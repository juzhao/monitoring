#!/bin/bash
set -euo pipefail
if [ -n "${DEBUG:-}" ] ; then
    set -x
fi

declare -a components=()

if [[ ${#components[@]} -eq 0 ]]
then
    components=( "alertmanager" "cluster_monitoring_operator" "grafana" "kube_state_metrics" "openshift_state_metrics" "node_exporter" "prometheus_adapter" "prometheus" "prometheus_operator" "telemeter_client" "thanos_querier" "project_info" )
fi


NAMESPACE=openshift-monitoring
DATE=`date +%Y%m%d_%H%M%S`
target=${target:-"monitoring-$DATE"}
logs_folder="$target/logs"
project_folder="$target/project"
alertmanager_folder="$target/alertmanager"
cluster_monitoring_operator_folder="$target/cluster-monitoring-operator"
grafana_folder="$target/grafana"
openshift_state_metrics_folder="$target/openshift-state-metrics"
kube_state_metrics_folder="$target/kube-state-metrics"
node_exporter_folder="$target/node-exporter"
prometheus_adapter_folder="$target/prometheus-adapter"
prometheus_folder="$target/prometheus"
prometheus_operator_folder="$target/prometheus-operator"
telemeter_client_folder="$target/telemeter-client"
thanos_querier_folder="$target/thanos-querier"

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
  oc -n $NAMESPACE get namespace $NAMESPACE -o yaml > $project_folder/monitoring-project-info
  echo -- Events
  oc -n $NAMESPACE get events > $project_folder/events
  # Don't get the secrets content for security reasons
  echo -- Secrets
  oc -n $NAMESPACE describe secrets > $project_folder/secrets

  resource_types=(configmaps daemonsets deployment services routes serviceaccounts statefulset persistentvolumeclaims pods prometheus prometheusrules alertmanagers servicemonitors)
  for resource_type in ${resource_types[@]}
  do
    echo -- Extracting $resource_type ...
    dump_resource_items $resource_type
  done
  dump_persistent_volumes
}

# Output alertmanager environment values and pod logs
check_alertmanager() {
  echo -- Checking alertmanager environment values and pod logs
  alertmanager_pods=$(oc -n $NAMESPACE get pods -l app=alertmanager -o jsonpath={.items[*].metadata.name})
  mkdir $alertmanager_folder
  for pod in $alertmanager_pods
  do
    echo ---- alertmanager pod: $pod
    get_env $pod $alertmanager_folder
    get_pod_logs $pod $alertmanager_folder
  done
}

# Output cluster_monitoring_operator environment values and pod logs
check_cluster_monitoring_operator() {
  echo -- Checking cluster_monitoring_operator environment values and pod logs
  cluster_monitoring_operator_pods=$(oc -n $NAMESPACE get pods -l app=cluster-monitoring-operator -o jsonpath={.items[*].metadata.name})
  mkdir $cluster_monitoring_operator_folder
  for pod in $cluster_monitoring_operator_pods
  do
    echo ---- cluster_monitoring_operator pod: $pod
    get_env $pod $cluster_monitoring_operator_folder
    get_pod_logs $pod $cluster_monitoring_operator_folder
  done
}

# Output grafana environment values and pod logs
check_grafana() {
  echo -- Checking grafana environment values and pod logs
  grafana_pods=$(oc -n $NAMESPACE get pods -l app=grafana -o jsonpath={.items[*].metadata.name})
  mkdir $grafana_folder
  for pod in $grafana_pods
  do
    echo ---- grafana pod: $pod
    get_env $pod $grafana_folder
    get_pod_logs $pod $grafana_folder
  done
}

# Output kube_state_metrics environment values and pod logs
check_kube_state_metrics() {
  echo -- Checking kube_state_metrics environment values and pod logs
  kube_state_metrics_pods=$(oc -n $NAMESPACE get pods -l app=kube-state-metrics -o jsonpath={.items[*].metadata.name})
  mkdir $kube_state_metrics_folder
  for pod in $kube_state_metrics_pods
  do
    echo ---- kube_state_metrics pod: $pod
    get_env $pod $kube_state_metrics_folder
    get_pod_logs $pod $kube_state_metrics_folder
  done
}

# Output openshift_state_metrics environment values and pod logs
check_openshift_state_metrics() {
  echo -- Checking openshift_state_metrics environment values and pod logs
  openshift_state_metrics_pods=$(oc -n $NAMESPACE get pods -l k8s-app=openshift-state-metrics -o jsonpath={.items[*].metadata.name})
  mkdir $openshift_state_metrics_folder
  for pod in $openshift_state_metrics_pods
  do
    echo ---- openshift_state_metrics pod: $pod
    get_env $pod $openshift_state_metrics_folder
    get_pod_logs $pod $openshift_state_metrics_folder
  done
}

# Output thanos_querier environment values and pod logs
check_thanos_querier() {
  echo -- Checking thanos_querier environment values and pod logs
  thanos_querier_pods=$(oc -n $NAMESPACE get pods -l app.kubernetes.io/name=thanos_querier -o jsonpath={.items[*].metadata.name})
  mkdir $thanos_querier_folder
  for pod in $thanos_querier_pods
  do
    echo ---- thanos_querier pod: $pod
    get_env $pod $thanos_querier_folder
    get_pod_logs $pod $thanos_querier_folder
  done
}

# Output node_exporter environment values and pod logs
check_node_exporter() {
  echo -- Checking node_exporter environment values and pod logs
  node_exporter_pods=$(oc -n $NAMESPACE get pods -l app=node-exporter -o jsonpath={.items[*].metadata.name})
  mkdir $node_exporter_folder
  for pod in $node_exporter_pods
  do
    echo ---- node_exporter pod: $pod
    get_env $pod $node_exporter_folder
    get_pod_logs $pod $node_exporter_folder
  done
}

# Output prometheus_adapter environment values and pod logs
check_prometheus_adapter() {
  echo -- Checking prometheus_adapter environment values and pod logs
  prometheus_adapter_pods=$(oc -n $NAMESPACE get pods -l name=prometheus-adapter -o jsonpath={.items[*].metadata.name})
  mkdir $prometheus_adapter_folder
  for pod in $prometheus_adapter_pods
  do
    echo ---- prometheus_adapter pod: $pod
    get_env $pod $prometheus_adapter_folder
    get_pod_logs $pod $prometheus_adapter_folder
  done
}

# Output prometheus environment values and pod logs
check_prometheus() {
  echo -- Checking prometheus environment values and pod logs
  prometheus_pods=$(oc -n $NAMESPACE get pods -l app=prometheus -o jsonpath={.items[*].metadata.name})
  mkdir $prometheus_folder
  for pod in $prometheus_pods
  do
    echo ---- prometheus pod: $pod
    get_env $pod $prometheus_folder
    get_pod_logs $pod $prometheus_folder
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


# Output telemeter_client environment values and pod logs
check_telemeter_client() {
  echo -- Checking telemeter_client environment values and pod logs
  telemeter_client_pods=$(oc -n $NAMESPACE get pods -l k8s-app=telemeter-client -o jsonpath={.items[*].metadata.name})
  mkdir $telemeter_client_folder
  for pod in $telemeter_client_pods
  do
    echo ---- telemeter_client pod: $pod
    get_env $pod $telemeter_client_folder
    get_pod_logs $pod $telemeter_client_folder
  done
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
