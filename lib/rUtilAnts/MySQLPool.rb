#--
# Copyright (c) 2011 Muriel Salvan (murielsalvan@users.sourceforge.net)
# Licensed under the terms specified in LICENSE file. No warranty is provided.
#++

module RUtilAnts

  module MySQLPool

    class MissingExistingConnectionError < RuntimeError
    end

    class MissingConnectionFromPoolError < RuntimeError
    end

    class MissingPreparedStatementFromPoolError < RuntimeError
    end

    # Set these methods into the Object namespace
    def self.initializeMySQLPool
      Object.module_eval('include RUtilAnts::MySQLPool')
    end

    # Create a MySQL connection to a MySQL database.
    # Keep connections in a pool with counters.
    # Reuse existing connections.
    # If the given password is nil, we force the reuse of an existing connection.
    #
    # Parameters:
    # * *iHost* (_String_): The host to connect to
    # * *iDBName* (_String_): The MySQL database name to connect to
    # * *iUser* (_String_): The user
    # * *iPassword* (_String_): The password. If nil, this will only try to reuse an existing connection [optional = nil]
    # Return:
    # * _Exception_: An error, or nil in case of success
    # * _MySQL_: The MySQL connection, or nil in case of failure
    def connectToMySQL(iHost, iDBName, iUser, iPassword = nil)
      rError = nil
      rMySQL = nil

      if (defined?($RUtilAnts_MySQLPool_Pool) == nil)
        # The pool: connection, counters and prepared statements per host/dbname/user
        # map< [ HostName, DBName, UserName ], [ MySQLConnection, Counter, map< SQLString, [ MySQLPreparedStatement, Counter ] > ] >
        $RUtilAnts_MySQLPool_Pool = {}
      end
      lDBKey = [ iHost, iDBName, iUser ]
      if ($RUtilAnts_MySQLPool_Pool[lDBKey] == nil)
        if (iPassword == nil)
          # This is a problem: we want an existing connection, but none exists.
          rError = MissingExistingConnectionError.new("An existing connection should already exist for #{lDBKey.inspect}")
        else
          # Create the connection
          require 'mysql'
          begin
            lMySQL = Mysql.new(iHost, iUser, iPassword, iDBName)
#            lMySQL = Mysql.init
#            lMySQL.options(Mysql::OPT_CONNECT_TIMEOUT, 28800)
#            lMySQL.options(Mysql::OPT_READ_TIMEOUT, 28800)
#            lMySQL.options(Mysql::OPT_WRITE_TIMEOUT, 28800)
#            lMySQL.real_connect(iHost, iUser, iPassword, iDBName)
          rescue Exception
            logErr "Error while creating MySQL connection to #{lDBKey.inspect}: #{$!}.\n#{$!.backtrace.join("\n")}"
            rError = $!
            lMySQL = nil
          end
          if (rError == nil)
            $RUtilAnts_MySQLPool_Pool[lDBKey] = [ lMySQL, 0, {} ]
          else
            $RUtilAnts_MySQLPool_Pool[lDBKey] = nil
          end
        end
      end
      if ((rError == nil) and
          ($RUtilAnts_MySQLPool_Pool[lDBKey] != nil))
        # Increase the count of clients to this connection
        $RUtilAnts_MySQLPool_Pool[lDBKey][1] += 1
        rMySQL = $RUtilAnts_MySQLPool_Pool[lDBKey][0]
      end

      return rError, rMySQL
    end

    # Close a MySQL connection created with connectToMySQL
    #
    # Parameters:
    # * *iMySQLConnection* (_MySQL_): The MySQL connection to close
    def closeMySQL(iMySQLConnection)
      # Find the connection
      if (defined?($RUtilAnts_MySQLPool_Pool) == nil)
        $RUtilAnts_MySQLPool_Pool = {}
      end
      lDBKey = findMySQLConnectionKey(iMySQLConnection)
      $RUtilAnts_MySQLPool_Pool[lDBKey][1] -= 1
      if ($RUtilAnts_MySQLPool_Pool[lDBKey][1] == 0)
        # Close for real
        $RUtilAnts_MySQLPool_Pool[lDBKey][0].close
        $RUtilAnts_MySQLPool_Pool[lDBKey] = nil
      end
    end

    # Setup a MySQL connection, and ensure it is closed once the client code ends.
    #
    # Parameters:
    # * *iHost* (_String_): The host to connect to
    # * *iDBName* (_String_): The MySQL database name to connect to
    # * *iUser* (_String_): The user
    # * *iPassword* (_String_): The password. If nil, this will only try to reuse an existing connection [optional = nil]
    # * *CodeBlock*: The code executed with the MySQL connection
    # ** *iMySQL* (_MySQL_): The MySQL connection
    # Return:
    # * _Exception_: An error, or nil in case of success
    def setupMySQLConnection(iHost, iDBName, iUser, iPassword = nil)
      rError = nil

      rError, lMySQL = connectToMySQL(iHost, iDBName, iUser, iPassword)
      if (rError == nil)
        begin
          yield(lMySQL)
        ensure
          closeMySQL(lMySQL)
        end
      end

      return rError
    end

    # Get a prepared statement for a given SQL string of a given MySQL connection.
    # Use the cache of prepared statements.
    #
    # Parameters:
    # * *iMySQLConnection* (_MySQL_): The MySQL connection
    # * *iStrSQL* (_String_): The SQL statement to prepare
    # * *iAdditionalOptions* (<em>map<Symbol,Object></em>): Additional options [optional = {}]
    # ** *:LeaveOpen* (_Boolean_): Do we NOT close the opened statement once it is not used anymore ? [optional = false]
    # Return:
    # * <em>MySQL::Statement</em>: The MySQL statement
    def getPreparedStatement(iMySQLConnection, iStrSQL, iAdditionalOptions = {})
      # Parse options
      lLeaveOpen = iAdditionalOptions[:LeaveOpen] || false
      # Find the prepared statements set
      lPreparedStatements = $RUtilAnts_MySQLPool_Pool[findMySQLConnectionKey(iMySQLConnection)][2]
      if (lPreparedStatements[iStrSQL] == nil)
        # Create a new one
        lPreparedStatements[iStrSQL] = [
          iMySQLConnection.prepare(iStrSQL),
          0
        ]
      end
      if (lLeaveOpen)
        # We set its counter to -1
        lPreparedStatements[iStrSQL][1] = -1
      elsif (lPreparedStatements[iStrSQL][1] != -1)
        # We increment its usage counter
        lPreparedStatements[iStrSQL][1] += 1
      end

      return lPreparedStatements[iStrSQL][0]
    end

    # Close a previously created prepared statement using getPreparedStatement.
    #
    # Parameters:
    # * *iMySQLConnection* (_MySQL_): The MySQL connection
    # * *iPreparedStatement* (<em>MySQL::Statement</em>): The MySQL prepared statement
    def closePreparedStatement(iMySQLConnection, iPreparedStatement)
      lPreparedStatements = $RUtilAnts_MySQLPool_Pool[findMySQLConnectionKey(iMySQLConnection)][2]
      lFound = false
      lPreparedStatements.each do |iStrSQL, ioPreparedStatementInfo|
        if (ioPreparedStatementInfo[0] == iPreparedStatement)
          # Found it
          if (ioPreparedStatementInfo[1] != -1)
            ioPreparedStatementInfo[1] -= 1
            if (ioPreparedStatementInfo[1] == 0)
              # Close it for real
              ioPreparedStatementInfo[1].close
              lPreparedStatements[iStrSQL] = nil
            end
          end
          lFound = true
        end
      end
      if (!lFound)
        raise MissingPreparedStatementFromPoolError.new("Prepared statement #{iPreparedStatement.inspect} can't be found among the pool of MySQL connection #{iMySQLConnection.inspect}")
      end
    end

    # Setup a prepared statement, and ensure it will be closed
    #
    # Parameters:
    # * *iMySQLConnection* (_MySQL_): The MySQL connection
    # * *iStrSQL* (_String_): The SQL statement to prepare
    # * *iAdditionalOptions* (<em>map<Symbol,Object></em>): Additional options [optional = {}]
    # ** *:LeaveOpen* (_Boolean_): Do we NOT close the opened statement once it is not used anymore ? [optional = false]
    # * *CodeBlock*: The code executed once the statement is prepared
    # ** *iPreparedStatement* (<em>MySQL::Statement</em>): The prepared statement
    def setupPreparedStatement(iMySQLConnection, iStrSQL, iAdditionalOptions = {})
      lStatement = getPreparedStatement(iMySQLConnection, iStrSQL, iAdditionalOptions)
      begin
        yield(lStatement)
      ensure
        closePreparedStatement(iMySQLConnection, lStatement)
      end
    end

    private

    # Find the MySQL connection key
    #
    # Parameters:
    # * *iMySQLConnection* (_MySQL_): The MySQL connection
    # Return:
    # * _String_: Host name, or nil if none
    # * _String_: DB name
    # * _String_: User name
    def findMySQLConnectionKey(iMySQLConnection)
      rHostName = nil
      rDBName = nil
      rUserName = nil

      $RUtilAnts_MySQLPool_Pool.each do |iDBKey, ioConnectionInfo|
        iMySQL = ioConnectionInfo[0]
        if (iMySQLConnection == iMySQL)
          # Found it
          rHostName, rDBName, rUserName = iDBKey
          break
        end
      end
      if (rHostName == nil)
        raise MissingConnectionFromPoolError.new("Unable to find connection #{iMySQLConnection.inspect} among the MySQL connections pool.")
      end

      return rHostName, rDBName, rUserName
    end

  end

end
