#!/bin/bash

set -ex

function log {
  timestamp=$(date)
  echo "$timestamp: $1"       #stdout
  echo "$timestamp: $1" 1>&2; #stderr
}

log "Running Zeppelin CSD control script..."
log "Detected CDH_VERSION of [$CDH_VERSION]"
log "Got command as $1"

case $1 in
  (start)
    # Set java path
    if [ -n "$JAVA_HOME" ]; then
      log "JAVA_HOME added to path as $JAVA_HOME"
      export PATH=$JAVA_HOME/bin:$PATH
    else
      log "JAVA_HOME not set"
    fi
    # Set Zeppelin conf
    export ZEPPELIN_CONF_DIR="$CONF_DIR/zeppelin-conf"
    if [ ! -d "$ZEPPELIN_CONF_DIR" ]; then
      log "Could not find zeppelin-conf directory at $ZEPPELIN_CONF_DIR"
      exit 3
    fi

    # Config Interpreters
    INTERPRETER_CONF="$ZEPPELIN_CONF_DIR/interpreter.json"

    function config_python_interpreter {
      INTERPRETER_ID="$1" # some ID like 2DBBKRGYD
      INTERPRETER_NAME="$2" 

      if [ -z "$PYTHON_INTERPRETER_EXEC" ]; then
        log "No executable for python, skipping interpreter setup"
        sed -i "s#{{PYTHON_INTERPRETER_BINDING}}##g" "$INTERPRETER_CONF"
        sed -i "s#{{PYTHON_INTERPRETER_CONFIG}}##g" "$INTERPRETER_CONF"
      else
        TEMP_CONF="$ZEPPELIN_CONF_DIR/python.interpreter.json"
        sed -i "s#{{INTERPRETER_ID}}#$INTERPRETER_ID#g" "$TEMP_CONF"
        sed -i "s#{{INTERPRETER_NAME}}#$INTERPRETER_NAME#g" "$TEMP_CONF"

        sed -i "s#{{PYTHON_INTERPRETER_EXEC}}#$PYTHON_INTERPRETER_EXEC#g" "$TEMP_CONF"
        sed -i "s#{{PYTHON_INTERPRETER_MODE_FOR_NOTE}}#$PYTHON_INTERPRETER_MODE_FOR_NOTE#g" "$TEMP_CONF"
        sed -i "s#{{PYTHON_INTERPRETER_MODE_FOR_USER}}#$PYTHON_INTERPRETER_MODE_FOR_USER#g" "$TEMP_CONF"

        sed -e "/{{PYTHON_INTERPRETER_CONFIG}}/ {" -e "r $TEMP_CONF" -e 'd' -e '}' -i "$INTERPRETER_CONF"
        sed -i "s#{{PYTHON_INTERPRETER_BINDING}}#\"$INTERPRETER_ID\",#g" "$INTERPRETER_CONF"
      fi
    }

    config_python_interpreter "2DBBKRGYD" "python"

    # Config Shiro auth
    SHIRO_CONF="$ZEPPELIN_CONF_DIR/shiro.ini"
    if [ "$ZEPPELIN_SHIRO_ENABLED" == "false" ]; then
      mv "$SHIRO_CONF" "${SHIRO_CONF}.template"
    fi
    #Add link to interpreter permissions so it is maintained between restarts
    ln -s "${ZEPPELIN_DATA_DIR}/notebook-authorization.json" "${ZEPPELIN_CONF_DIR}/notebook-authorization.json"

    log "Starting the Zeppelin server"
    exec env ZEPPELIN_JAVA_OPTS="-Xms$ZEPPELIN_MEMORY -Xmx$ZEPPELIN_MEMORY" $ZEPPELIN_HOME/bin/zeppelin.sh
    ;;
  (*)
    echo "Don't understand [$1]"
    exit 1
    ;;
esac
