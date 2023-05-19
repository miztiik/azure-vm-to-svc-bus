
param vmName string
param deploymentParams object
param repoName string
param svc_bus_ns_name string
param svc_bus_q_name string
param tags object
param deploy_app_script bool = false

resource r_vm_1 'Microsoft.Compute/virtualMachines@2022-03-01' existing = {
  name: vmName
}

var command_to_clone_repo_with_vars = '''
REPO_NAME="REPO_NAME_VAR" && \
GIT_REPO_URL="https://github.com/miztiik/$REPO_NAME.git" && \
cd /var && \
rm -rf /var/$REPO_NAME && \
git clone $GIT_REPO_URL && \
cd /var/$REPO_NAME && \
chmod +x /var/$REPO_NAME/modules/vm/bootstrap_scripts/deploy_app.sh && \
bash /var/$REPO_NAME/modules/vm/bootstrap_scripts/deploy_app.sh &
'''

var command_to_clone_repo = replace(command_to_clone_repo_with_vars, 'REPO_NAME_VAR', repoName)

resource r_deploy_script_1 'Microsoft.Compute/virtualMachines/runCommands@2022-03-01' = {
  parent: r_vm_1
  name:   '${deploymentParams.enterprise_name_suffix}_${deploymentParams.global_uniqueness}_script_1'
  location: deploymentParams.location
  tags: tags
  properties: {
    asyncExecution: false
    source: {
        script: command_to_clone_repo
      }

  }
}


var script_to_execute_with_vars = '''
REPO_NAME="REPO_NAME_VAR" && \
export SVC_BUS_FQDN="SVC_BUS_FQDN_VAR" && \
export SVC_BUS_Q_NAME="SVC_BUS_Q_NAME_VAR" && \
python3 /var/$REPO_NAME/app/function_code/az_producer_for_svc_bus &
'''

var script_to_execute = replace( replace( replace(script_to_execute_with_vars, 'SVC_BUS_FQDN_VAR', svc_bus_ns_name), 'SVC_BUS_Q_NAME_VAR',svc_bus_q_name),'REPO_NAME_VAR', repoName)

resource r_deploy_script_2 'Microsoft.Compute/virtualMachines/runCommands@2022-03-01' = if (deploy_app_script) {
  parent: r_vm_1
    name:   '${deploymentParams.enterprise_name_suffix}_${deploymentParams.global_uniqueness}_script_2'
  location: deploymentParams.location
  tags: tags
  properties: {
    asyncExecution: true
    runAsUser: 'root'
    parameters: [
      {
        name: 'EVENTS_TO_PRODUCE'
        value: '1'
      }
    ]
    source: {
        script: script_to_execute
      }
      timeoutInSeconds: 600
  }
  dependsOn: [
    r_deploy_script_1
  ]
}


// Troublshooting
/*
script_location = '/var/lib/waagent/run-command-handler/download/VM_NAME_script_deployment/0/script.sh'
output_location = '/var/lib/waagent/run-command-handler/download/m-web-srv-004_004_script_deployment/0'
*/


/*

resource runSetupCommands 'Microsoft.Compute/virtualMachines/runCommands@2022-03-01' = {
  name: '${i}-${vmName}/ssh'
  location: location
  properties: {
    source: {
        script: 'sed -i \'s/#Port 22/Port 45/g\' /etc/ssh/sshd_config && systemctl restart sshd'
      }
  }
}
*/
