#!/bin/bash

# Set recommended umask of "u=,g=w,o=rwx" (0027)
umask 0027

# Setup Catalina Opts
: ${CATALINA_CONNECTOR_PROXYNAME:=}
: ${CATALINA_CONNECTOR_PROXYPORT:=}
: ${CATALINA_CONNECTOR_SCHEME:=http}
: ${CATALINA_CONNECTOR_SECURE:=false}

: ${CATALINA_OPTS:=}

: ${JAVA_OPTS:=}

: ${APPLICATION_MODE:=}

CATALINA_OPTS="${CATALINA_OPTS} -DcatalinaConnectorProxyName=${CATALINA_CONNECTOR_PROXYNAME}"
CATALINA_OPTS="${CATALINA_OPTS} -DcatalinaConnectorProxyPort=${CATALINA_CONNECTOR_PROXYPORT}"
CATALINA_OPTS="${CATALINA_OPTS} -DcatalinaConnectorScheme=${CATALINA_CONNECTOR_SCHEME}"
CATALINA_OPTS="${CATALINA_OPTS} -DcatalinaConnectorSecure=${CATALINA_CONNECTOR_SECURE}"

JAVA_OPTS="${JAVA_OPTS} ${CATALINA_OPTS}"

ARGS="$@"

echo "Init dbconfig.xml (database)"
# If configuration is present
if [[ -n "${JIRA_DATABASE_SERVER}" && -n "${JIRA_DATABASE_NAME}" && -n "${JIRA_DATABASE_USERNAME}" && -n "${JIRA_DATABASE_PASSWORD}" ]];then
	# At the first launch
	if [ ! -f "${JIRA_HOME}/dbconfig.xml" ]; then
		cp "${JIRA_INSTALL}/dbconfig.xml.template" "${JIRA_HOME}/dbconfig.xml"
	fi
	# Update values
	xmlstarlet ed --inplace -u "/jira-database-config/jdbc-datasource/url" --value "jdbc:postgresql://${JIRA_DATABASE_SERVER}:${JIRA_DATABASE_PORT}/${JIRA_DATABASE_NAME}" "${JIRA_HOME}/dbconfig.xml"
	xmlstarlet ed --inplace -u "/jira-database-config/jdbc-datasource/username" --value "${JIRA_DATABASE_USERNAME}" "${JIRA_HOME}/dbconfig.xml"
	xmlstarlet ed --inplace -u "/jira-database-config/jdbc-datasource/password" --value "${JIRA_DATABASE_PASSWORD}" "${JIRA_HOME}/dbconfig.xml"
	
fi

# configure clustering if properties file was specified
if [ -n "${JIRA_CLUSTER_CONFIG}" ]; then
    #NEW_NODE_ID=$(uuidgen)
    echo "jira.node.id=${HOSTNAME}" >> "${JIRA_CLUSTER_CONFIG}"
    echo "jira.shared.home=${JIRA_SHARED_HOME}" >> "${JIRA_CLUSTER_CONFIG}"
    echo "${JIRA_CLUSTER_CONFIG}:"
    cat "${JIRA_CLUSTER_CONFIG}"
fi

export JVM_SUPPORT_RECOMMENDED_ARGS="-Djavax.net.ssl.trustStore=${JIRA_HOME}/jre/lib/security/jssecacerts -Dcluster.node.name=$HOSTNAME"
# if [ -f ${JIRA_HOME}/jre/lib/security/jssecacerts ]; then 
#     JVM_SUPPORT_RECOMMENDED_ARGS="${JVM_SUPPORT_RECOMMENDED_ARGS} -Djavax.net.ssl.trustStore=${JIRA_HOME}/jre/lib/security/jssecacerts"
# fi
#-Djavax.net.ssl.trustStore=${JIRA_SHARED_HOME}/cacerts

# Start jira as the correct user.
if [ "${UID}" -eq 0 ]; then
    echo "User is currently root. Will change directory ownership to ${RUN_USER}:${RUN_GROUP}, then downgrade permission to ${RUN_USER}"
    PERMISSIONS_SIGNATURE=$(stat -c "%u:%U:%a" "${JIRA_HOME}")
    EXPECTED_PERMISSIONS=$(id -u ${RUN_USER}):${RUN_USER}:700
    if [ "${PERMISSIONS_SIGNATURE}" != "${EXPECTED_PERMISSIONS}" ]; then
        echo "Updating permissions for JIRA_AGENT_HOME"
        mkdir -p "${JIRA_HOME}/lib" &&
            chmod -R 700 "${JIRA_HOME}" &&
            chown -R "${RUN_USER}:${RUN_GROUP}" "${JIRA_HOME}"
    fi
    # Now drop privileges
    echo "Executing with downgraded permissions"
    exec su -s /bin/bash "${RUN_USER}" -c java -jar "${JIRA_INSTALL}/bin/start-jira.sh ${ARGS}"
else
    echo "Executing with default permissions"
    exec "${JIRA_INSTALL}"/bin/start-jira.sh ${ARGS}
fi
