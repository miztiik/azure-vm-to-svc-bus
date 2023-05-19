
param deploymentParams object
param tags object
param r_usr_mgd_identity_id string
param delayInSeconds int = 45
param delay_multiple int = 1

param baseTime string = utcNow('yyyy-MM-dd-HH-mm-ss')

resource r_sleep_delay 'Microsoft.Resources/deploymentScripts@2020-10-01' =  [for i in range(0, delay_multiple): {
  name: 'add_deployment_delay_${i}_${deploymentParams.global_uniqueness}'
  location: deploymentParams.location
  tags: tags
  kind: 'AzureCLI'
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${r_usr_mgd_identity_id}': {}
    }
  }
  properties: {
    azCliVersion: '2.30.0'
    timeout: 'PT15M'
    retentionInterval: 'PT1H'
    forceUpdateTag: baseTime
    environmentVariables: [
      {
        name: 'INITIAL_DELAY'
        value: '${delayInSeconds}s'
      }
    ]
    scriptContent: '''
      #!/bin/bash
      set -e

      echo -e \"Sleeping for ${INITIAL_DELAY} seconds\"
      sleep ${INITIAL_DELAY}
    '''
  }
}]
