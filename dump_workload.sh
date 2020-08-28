#!/bin/bash
set -euo pipefail
if [ -n "${DEBUG:-}" ] ; then
    set -x
fi

declare -a components=()

if [[ ${#components[@]} -eq 0 ]]
then
    components=( "prometheus_operator" "prometheus_user_workload" "thanos_ruler_user_workload" "project_info" "alerts" "rules" )
fi


NAMESPACE=openshift-user-workload-monitoring
DATE=`date +%Y%m%d_%H%M%S`
target=${target:-"user-monitoring-$DATE"}
logs_folder="$target/logs"
project_folder="$target/project"
prometheus_operator_folder="$target/prometheus-operator"
prometheus_user_workload_folder="$target/prometheus-user-workload"
thanos_ruler_user_workload_folder="$target/thanos-ruler-user-workload"
alerts_folder="$target/alerts"
rules_folder="$target/rules"
token=`oc -n openshift-user-workload-monitoring sa get-token thanos-ruler`

# Output resource items
dump_resource_items() {
  local type=$1
  mkdir $project_folder/$type
  for resource in `oc -n $NAMESPACE get $type -o jsonpath='{.items[*].metadata.name}'`
  do
    oc -n $NAMESPACE get $type $resource -o yaml > $project_folder/$type/$resource
  done
}

# Output persistent volumes
dump_persistent_volumes() {
  mkdir $project_folder/persistentvolumes
  echo -- Extracting persistentvolumes ...
  for pv in `oc get persistentvolumes -o 'go-template={{range $pv := .items}}{{if $pv.spec.claimRef}}{{if eq $pv.spec.claimRef.namespace "'${NAMESPACE}'"}}{{printf "%s\n"  $pv.metadata.name}}{{end}}{{end}}{{end}}'`
  do
    oc -n $NAMESPACE get persistentvolumes $pv -o yaml > $project_folder/persistentvolumes/$pv
  done
}

# Output resources in resource_types list
check_project_info() {
  mkdir $project_folder
  echo Getting general objects
  echo -- Nodes Description
  oc -n $NAMESPACE describe nodes > $project_folder/nodes
  echo -- Project Description
  oc -n $NAMESPACE get namespace $NAMESPACE -o yaml > $project_folder/user-monitoring-project-info
  echo -- Events
  oc -n $NAMESPACE get events > $project_folder/events
  # Don't get the secrets content for security reasons
  echo -- Secrets
  oc -n $NAMESPACE describe secrets > $project_folder/secrets

  resource_types=(configmaps deployment services routes serviceaccounts statefulset persistentvolumeclaims pods prometheus prometheusrules thanosrulers servicemonitors)
  for resource_type in ${resource_types[@]}
  do
    echo -- Extracting $resource_type ...
    dump_resource_items $resource_type
  done
  dump_persistent_volumes
}

# Output prometheus_user_workload environment values and pod logs
check_prometheus_user_workload() {
  echo -- Checking prometheus_user_workload environment values and pod logs
  prometheus_user_workload_pods=$(oc -n $NAMESPACE get pods -l app=prometheus -o jsonpath={.items[*].metadata.name})
  mkdir $prometheus_user_workload_folder
  for pod in $prometheus_user_workload_pods
  do
    echo ---- prometheus_user_workload pod: $pod
    get_env $pod $prometheus_user_workload_folder
    get_pod_logs $pod $prometheus_user_workload_folder
  done
}

# Output thanos_ruler_user_workload environment values and pod logs
check_thanos_ruler_user_workload() {
  echo -- Checking thanos_ruler_user_workload environment values and pod logs
  thanos_ruler_user_workload_pods=$(oc -n $NAMESPACE get pods -l app=thanos-ruler -o jsonpath={.items[*].metadata.name})
  mkdir $thanos_ruler_user_workload_folder
  for pod in $thanos_ruler_user_workload_pods
  do
    echo ---- thanos_ruler_user_workload pod: $pod
    get_env $pod $thanos_ruler_user_workload_folder
    get_pod_logs $pod $thanos_ruler_user_workload_folder
  done
}


# Output prometheus_operator environment values and pod logs
check_prometheus_operator() {
  echo -- Checking prometheus_operator environment values and pod logs
  prometheus_operator_pods=$(oc -n $NAMESPACE get pods -l app.kubernetes.io/name=prometheus-operator -o jsonpath={.items[*].metadata.name})
  mkdir $prometheus_operator_folder
  for pod in $prometheus_operator_pods
  do
    echo ---- prometheus_operator pod: $pod
    get_env $pod $prometheus_operator_folder
    get_pod_logs $pod $prometheus_operator_folder
  done
}

# Output user project alerts in the cluster
check_alerts() {
  echo -- Output alerts in the cluster
  mkdir $alerts_folder
  oc -n openshift-user-workload-monitoring exec -c thanos-ruler thanos-ruler-user-workload-0 -- curl -k -H "Authorization: Bearer $token" 'https://thanos-ruler.openshift-user-workload-monitoring.svc:9091/api/v1/alerts' | jq > $alerts_folder/alerts.txt
}

# Output user project prometheus rules in the cluster
check_rules() {
  echo -- Output user project prometheus rules in the cluster
  mkdir $rules_folder
  oc -n openshift-user-workload-monitoring exec -c thanos-ruler thanos-ruler-user-workload-0 -- curl -k -H "Authorization: Bearer $token" 'https://thanos-ruler.openshift-user-workload-monitoring.svc:9091/api/v1/rules' | jq > $rules_folder/rules.txt
}


# Get env settings for containers
get_env() {
  local pod=$1
  local env_file=$2/$pod
  containers=$(oc -n $NAMESPACE get po $pod -o jsonpath='{.spec.containers[*].name}')
  for container in $containers
  do
    echo -- Environment Variables >> $env_file
    oc -n $NAMESPACE exec $pod -c $container -- env | sort >> $env_file
  done
}

# Get pod logs for all containers
get_pod_logs() {
  local pod=$1
  local logs_folder=$2/logs
  echo -- POD $1 Logs
  if [ ! -d "$logs_folder" ]
  then
    mkdir $logs_folder
  fi
  local containers=$(oc -n $NAMESPACE get po $pod -o jsonpath='{.spec.containers[*].name}')
  for container in $containers
  do
    oc -n $NAMESPACE logs $pod -c $container | nice xz > $logs_folder/$pod-$container.log.xz || oc -n $NAMESPACE logs $pod | nice xz > $logs_folder/$pod.log.xz || echo ---- Unable to get logs from pod $pod and container $container
  done
}

if [ ! -d ${target} ]
then
  mkdir -p $target
fi


echo Retrieving results to $target

for comp in "${components[@]}"
do
    eval "check_${comp}" || echo Unrecognized function check_${comp} to check component: ${comp}
done
