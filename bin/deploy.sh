#!/bin/bash
set -ex
# required env vars: CLUSTER_NAME, CONFIG_BRANCH, CONFIG_REPO, NAMESPACE,
# DEPLOYMENT_YAML, DEPLOYMENT_LOG_BASE_URL, DEPLOYMENT_NAME, DEPLOYMENT_VERSION,
# DEMO_NAME, DOMAIN
# TODO: move more of this script to python

BEDROCK_BIN=$(pwd)
. ${BEDROCK_BIN}/../docker/bin/set_git_env_vars.sh # sets DEPLOYMENT_DOCKER_IMAGE
pushd $(mktemp -d)
git clone --depth=1 -b ${CONFIG_BRANCH:=master} ${CONFIG_REPO} config_checkout
cd config_checkout

set -u
if [[ "${NAMESPACE}" == "bedrock-demo" ]]; then
    DEMO_DIR="${CLUSTER_NAME}/${NAMESPACE}"
    DEMO_DEPLOY="${DEMO_DIR}/${DEPLOYMENT_YAML}"
    DEMO_SVC="${DEMO_DIR}/bedrock-demo-${DEMO_NAME}-svc.yaml"
    DEMO_SVC_TEMPLATE="${DEMO_DIR}/bedrock-demo-2-svc.yaml"
    DEMO_INGRESS="${DEMO_DIR}/ingress.yaml"
    if [[ ! -e ${DEMO_DEPLOY} ]]; then
        cp ${CLUSTER_NAME}/bedrock-dev/deploy.yaml ${DEMO_DEPLOY}
        # TODO: more robust template demo name substitution
        sed -e s/2/${DEMO_NAME}/ ${DEMO_SVC_TEMPLATE} > ${DEMO_SVC}
        ${BEDROCK_BIN}/add_svc_ingress.py ${DEMO_SVC} ${DEMO_INGRESS} ${DOMAIN}
    fi
    sed -i -e "s|image: .*|image: ${DEPLOYMENT_DOCKER_IMAGE}|" ${DEMO_DEPLOY}
    git add ${DEMO_DEPLOY}
    git commit -m "set image to ${DEPLOYMENT_DOCKER_IMAGE} in ${DEMO_DEPLOY}" || echo "nothing new to commit"
else
    sed -i -e "s|image: .*|image: ${DEPLOYMENT_DOCKER_IMAGE}|" all-clusters/${NAMESPACE}/${DEPLOYMENT_YAML:=deploy.yaml}
    cp {all-clusters,${CLUSTER_NAME}}/${NAMESPACE}/${DEPLOYMENT_YAML}
    git add {all-clusters,${CLUSTER_NAME}}/${NAMESPACE}/${DEPLOYMENT_YAML}
    git commit -m "set image to ${DEPLOYMENT_DOCKER_IMAGE} in ${CLUSTER_NAME}" || echo "nothing new to commit"
fi
git push
DEPLOYMENT_VERSION=$(git rev-parse --short HEAD)

DEPLOYMENT_NAME=$(python3 -c "import yaml; print(yaml.load(open(\"$CLUSTER_NAME/$NAMESPACE/$DEPLOYMENT_YAML\"))['metadata']['name'])")
CHECK_URL=$DEPLOYMENT_LOG_BASE_URL/$NAMESPACE/$DEPLOYMENT_NAME/$DEPLOYMENT_VERSION
attempt_counter=0
max_attempts=120
set +x
until curl -sf $CHECK_URL; do
    if [ ${attempt_counter} -eq ${max_attempts} ]; then
        echo "Deployment incomplete"
        exit 1
    fi
    attempt_counter=$(($attempt_counter+1))
    sleep 10
done
popd
