// targetScope = 'subscription'

targetScope = 'resourceGroup'

// Parameters
param deploymentParams object
param identityParams object
param appConfigParams object
param storageAccountParams object
param logAnalyticsWorkspaceParams object

param serviceBusParams object

param vnetParams object
param vmParams object
param dceParams object

param brandTags object

param dateNow string = utcNow('yyyy-MM-dd-hh-mm')

param tags object = union(brandTags, {last_deployed:dateNow})


// Create Identity
module r_usr_mgd_identity 'modules/identity/create_usr_mgd_identity.bicep' = {
  name: '${deploymentParams.enterprise_name_suffix}_${deploymentParams.global_uniqueness}_usr_mgd_identity'
  params: {
    deploymentParams:deploymentParams
    identityParams:identityParams
    tags: tags
  }
}

//Create App Config
module r_appConfig 'modules/app_config/create_app_config.bicep' = {
  name: '${appConfigParams.appConfigNamePrefix}_${deploymentParams.global_uniqueness}_Config'
  params: {
    deploymentParams:deploymentParams
    appConfigParams: appConfigParams
    tags: tags
  }
}

// Create the Log Analytics Workspace
module r_logAnalyticsWorkspace 'modules/monitor/log_analytics_workspace.bicep' = {
  name: '${logAnalyticsWorkspaceParams.workspaceName}_${deploymentParams.global_uniqueness}_La'
  params: {
    deploymentParams:deploymentParams
    logAnalyticsWorkspaceParams: logAnalyticsWorkspaceParams
    tags: tags
  }
}


// Create Storage Account
module r_sa 'modules/storage/create_storage_account.bicep' = {
  name: '${storageAccountParams.storageAccountNamePrefix}_${deploymentParams.global_uniqueness}_Sa'
  params: {
    deploymentParams:deploymentParams
    storageAccountParams:storageAccountParams
    tags: tags
  }
}


// Create Storage Account - Blob container
module r_blob 'modules/storage/create_blob.bicep' = {
  name: '${storageAccountParams.storageAccountNamePrefix}_${deploymentParams.global_uniqueness}_Blob'
  params: {
    deploymentParams:deploymentParams
    storageAccountParams:storageAccountParams
    storageAccountName: r_sa.outputs.saName

    logAnalyticsWorkspaceId: r_logAnalyticsWorkspace.outputs.logAnalyticsPayGWorkspaceId
    enableDiagnostics: false
  }
  dependsOn: [
    r_sa
  ]
}


// Create the Service Bus
module r_svc_bus 'modules/integration/create_svc_bus.bicep' = {
  name: '${serviceBusParams.serviceBusNamePrefix}_${deploymentParams.global_uniqueness}_Svc_Bus'
  params: {
    deploymentParams:deploymentParams
    serviceBusParams:serviceBusParams
    tags: tags
  }
}


// Create the VNets
module r_vnet 'modules/vnet/create_vnet.bicep' = {
  name: '${vnetParams.vnetNamePrefix}_${deploymentParams.global_uniqueness}_Vnet'
  params: {
    deploymentParams:deploymentParams
    vnetParams:vnetParams
    tags: tags
  }
}

// Create Virtual Machine
module r_vm 'modules/vm/create_vm.bicep' = {
  name: '${vmParams.vmNamePrefix}_${deploymentParams.global_uniqueness}_Vm'
  params: {
    deploymentParams:deploymentParams
    r_usr_mgd_identity_name: r_usr_mgd_identity.outputs.usr_mgd_identity_name

    saName: r_sa.outputs.saName
    blobContainerName: r_blob.outputs.blobContainerName
    saPrimaryEndpointsBlob: r_sa.outputs.saPrimaryEndpointsBlob

    appConfigName: r_appConfig.outputs.appConfigName

    svc_bus_ns_name: r_svc_bus.outputs.svc_bus_ns_name

    vmParams: vmParams
    vnetName: r_vnet.outputs.vnetName

    logAnalyticsPayGWorkspaceId:r_logAnalyticsWorkspace.outputs.logAnalyticsPayGWorkspaceId

    linDataCollectionEndpointId: r_dataCollectionEndpoint.outputs.linDataCollectionEndpointId
    storeEventsDcrId: r_dataCollectionRule.outputs.storeEventsDcrId
    automationEventsDcrId: r_dataCollectionRule.outputs.automationEventsDcrId

    tags: tags
  }
  dependsOn: [
    r_vnet
  ]
}

// Create Data Collection Endpoint
module r_dataCollectionEndpoint 'modules/monitor/data_collection_endpoint.bicep' = {
  name: '${dceParams.endpointNamePrefix}_${deploymentParams.global_uniqueness}_Dce'
  params: {
    deploymentParams:deploymentParams
    dceParams: dceParams
    osKind: 'linux'
    tags: tags
  }
}



// Create the Data Collection Rule
module r_dataCollectionRule 'modules/monitor/data_collection_rule.bicep' = {
  name: '${logAnalyticsWorkspaceParams.workspaceName}_${deploymentParams.global_uniqueness}_Dcr'
  params: {
    deploymentParams:deploymentParams
    osKind: 'Linux'
    tags: tags

    storeEventsRuleName: 'storeEvents_Dcr'
    storeEventsLogFilePattern: '/var/log/miztiik*.json'
    storeEventscustomTableNamePrefix: r_logAnalyticsWorkspace.outputs.storeEventsCustomTableNamePrefix

    automationEventsRuleName: 'miztiikAutomation_Dcr'
    automationEventsLogFilePattern: '/var/log/miztiik-automation-*.log'
    automationEventsCustomTableNamePrefix: r_logAnalyticsWorkspace.outputs.automationEventsCustomTableNamePrefix
    
    managedRunCmdRuleName: 'miztiikManagedRunCmd_Dcr'
    managedRunCmdLogFilePattern: '/var/log/azure/run-command-handler/*.log'
    managedRunCmdCustomTableNamePrefix: r_logAnalyticsWorkspace.outputs.managedRunCmdCustomTableNamePrefix

    linDataCollectionEndpointId: r_dataCollectionEndpoint.outputs.linDataCollectionEndpointId
    logAnalyticsPayGWorkspaceName:r_logAnalyticsWorkspace.outputs.logAnalyticsPayGWorkspaceName
    logAnalyticsPayGWorkspaceId:r_logAnalyticsWorkspace.outputs.logAnalyticsPayGWorkspaceId

  }
  dependsOn: [
    r_logAnalyticsWorkspace
  ]
}


// Add Delay for Cosmos DB to be ready
module r_add_delay 'modules/bootstrap/add_delay.bicep'={
  name: 'deployment_delay_${deploymentParams.global_uniqueness}'
  params: {
    deploymentParams:deploymentParams
    r_usr_mgd_identity_id: r_usr_mgd_identity.outputs.usr_mgd_identity_id
    delayInSeconds: 60
    delay_multiple: 1
    tags: tags
  }
}

// Deploy Script on VM
module r_deploy_managed_run_cmd 'modules/bootstrap/run_command_on_vm.bicep'= {
  name: '${vmParams.vmNamePrefix}_${deploymentParams.global_uniqueness}_run_cmd'
  params: {
    deploymentParams:deploymentParams
    vmName: r_vm.outputs.vmName
    repoName: brandTags.project
    deploy_app_script: true
    svc_bus_ns_name: r_svc_bus.outputs.svc_bus_ns_name
    svc_bus_q_name: r_svc_bus.outputs.svc_bus_q_name
    tags: tags
  }
  dependsOn: [
    r_vm
  ]
}
