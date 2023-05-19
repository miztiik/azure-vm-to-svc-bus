# set -x
set -e

# Define colors for console output
GREEN="\e[32m"
RED="\e[31m"
BLUE="\e[34m"
CYAN="\e[36m"
YELLOW="\e[33m"
RESET="\e[0m"
# echo -e "${GREEN}This text is green.${RESET}"


# Set Global Variables
MAIN_BICEP_TEMPL_NAME="main.bicep"
LOCATION=$(jq -r '.parameters.deploymentParams.value.location' params.json)
SUB_DEPLOYMENT_PREFIX=$(jq -r '.parameters.deploymentParams.value.sub_deploymnet_prefix' params.json)
ENTERPRISE_NAME=$(jq -r '.parameters.deploymentParams.value.enterprise_name' params.json)
ENTERPRISE_NAME_SUFFIX=$(jq -r '.parameters.deploymentParams.value.enterprise_name_suffix' params.json)
GLOBAL_UNIQUENESS=$(jq -r '.parameters.deploymentParams.value.global_uniqueness' params.json)

RG_NAME="${ENTERPRISE_NAME}_${ENTERPRISE_NAME_SUFFIX}_${GLOBAL_UNIQUENESS}"
DEPLOYMENT_NAME="${SUB_DEPLOYMENT_PREFIX}_${ENTERPRISE_NAME_SUFFIX}_${GLOBAL_UNIQUENESS}_Deployment"

# # Generate and SSH key pair to pass the public key as parameter
# ssh-keygen -m PEM -t rsa -b 4096 -C '' -f ./miztiik.pem

# pubkeydata=$(cat miztiik.pem.pub)

DEPLOYMENT_OUTPUT_1=""

# Function Deploy all resources
function deploy_everything()
{

echo -e "${YELLOW} Create Resource Group ${RESET}" # Yellow
echo -e "  Initiate RG Deployment: ${CYAN}${RG_NAME}${RESET} at ${CYAN}${LOCATION}${RESET}"
RG_CREATION_OUTPUT=$(az group create -n $RG_NAME --location $LOCATION  | jq -r '.name')

if [ $? == 0 ]; then
    echo -e "${GREEN}   Resource group created successfully. ${RESET}"
else
    echo -e "${RED}   Resource group creation failed. ${RESET}"
    echo -e "${RED}   $RG_CREATION_OUTPUT ${RESET}"
    exit 1
fi


az bicep build --file $1

# Initiate Deployments
echo -e "${YELLOW} Initiate Deployments in RG ${RESET}" # Yellow
echo -e "  Deploy: ${CYAN}${DEPLOYMENT_NAME}${RESET} at ${CYAN}${LOCATION}${RESET}"

az deployment group create \
    --name ${DEPLOYMENT_NAME} \
    --resource-group $RG_NAME \
    --template-file $1 \
    --parameters @params.json


if [ $? == 0 ]; then
    echo -e "${GREEN}  Deployments success. ${RESET}"
else
    echo -e "${RED} Deployments failed. ${RESET}"
    exit 1
fi

}

# Publish the function App
function deploy_func_code(){

    FUNC_APP_NAME_PART_1=$(jq -r '.parameters.deploymentParams.value.enterprise_name_suffix' params.json)
    FUNC_APP_NAME_PART_2=$(jq -r '.parameters.funcParams.value.funcAppPrefix' params.json)
    FUNC_APP_NAME_PART_3="fn-app"
    GLOBAL_UNIQUENESS=$(jq -r '.parameters.deploymentParams.value.global_uniqueness' params.json)
    FUNC_APP_NAME=${FUNC_APP_NAME_PART_1}-${FUNC_APP_NAME_PART_2}-${FUNC_APP_NAME_PART_3}-${GLOBAL_UNIQUENESS}
    FUNC_APP_NAME="${FUNC_APP_NAME//_/-}"
    # echo "$FUNC_APP_NAME"

    FUNC_CODE_LOCATION="./app/function_code/store-backend-ops/"

    pushd ${FUNC_CODE_LOCATION}

    # Initiate Deployments
    echo -e "${YELLOW} Initiating Python Function Deployment ${RESET}" # Yellow
    echo -e "  Deploying code from ${CYAN}${FUNC_CODE_LOCATION}${RESET} to ${CYAN}${FUNC_APP_NAME}${RESET} \033[0m" # Green

    func azure functionapp publish ${FUNC_APP_NAME} --nozip
    popd
}




#########################################################################
#########################################################################
#########################################################################
#########################################################################


deploy_everything $MAIN_BICEP_TEMPL_NAME
deploy_func_code
