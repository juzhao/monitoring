#!/bin/bash
project=openshift-monitoring
prometheus_ip=`oc -n $project get pod -l statefulset.kubernetes.io/pod-name=prometheus-k8s-0 -ojsonpath="{..podIP"}`
alertmanager_ip=`oc -n $project get pod -l statefulset.kubernetes.io/pod-name=alertmanager-main-0 -ojsonpath="{..podIP"}`
grafana_ip=`oc -n $project get pod -l app=grafana -ojsonpath="{..podIP"}`
token=`oc -n $project sa get-token prometheus-k8s`
prometheus_route=`oc -n $project  get route | grep prometheus-k8s | awk '{print $2}'`


# check monitoring pods
funCheckPods() {
       echo "output pods under openshift-monitoring"
       oc -n $project get pod -o wide
}
# check monitoring images and check if errors in pod logs
funCheckImageAndLog() {
	for pod in $(oc get pod -n $project | grep -v NAME| awk '{print $1}')
	do
		echo pod: $pod
		echo -e "\n"
		oc -n $project get po $pod -o yaml | grep -i image: | uniq
		echo -e "\n"
		for container in $(oc -n $project get pods $pod -o jsonpath="{.spec.containers[*].name}")
		do
			echo container: $container
			oc -n $project logs -c $container $pod  | grep -e error -e Error -e Exception -e err -e "remote error" -e fail
			echo -e "\n"
		done
	done
}

# Check grafana
funCheckGrafana(){
        echo "Grafana pod IP is:" ${grafana_ip}
	oc -n openshift-monitoring exec -c prometheus prometheus-k8s-1 -- curl -k -H "Authorization: Bearer $token" https://${grafana_ip}:3000/api/health
        echo -e "\n"
}

# Check prometheus
funCheckPrometheus(){
        echo "Prometheus pod IP is:" ${prometheus_ip}
	oc -n openshift-monitoring exec -c prometheus prometheus-k8s-1 -- curl -k -H "Authorization: Bearer $token" https://${prometheus_ip}:9091/metrics | grep prometheus_rule_group_interval_seconds
        echo -e "\n"
}

# Check alertmanager if alert contains DeadMansSwitch
funCheckAlertmanager(){
        echo "Alertmanager pod IP is:" ${alertmanager_ip}
        echo "output alerts"
	oc -n openshift-monitoring exec -c prometheus prometheus-k8s-1  -- curl -k -H "Authorization: Bearer $token" https://${alertmanager_ip}:9095/api/v1/alerts | grep Watchdog | jq
        echo -e "\n"
}

funCheckTargetDown(){
        echo "prometheus route is:" ${prometheus_route}
        echo "the following target is down"
        curl -k -H "Authorization: Bearer $token" https://${prometheus_route}/targets | grep -i down
}

funCheckx509(){
        echo "prometheus route is:" ${prometheus_route}
        echo "x509 error see below"
        curl -k -H "Authorization: Bearer $token" https://${prometheus_route}/targets | grep -i x509
}

funCheckdeadline(){
        echo "prometheus route is:" ${prometheus_route}
        echo "context deadline exceeded error see below"
        curl -k -H "Authorization: Bearer $token" https://${prometheus_route}/targets | grep -i deadline
}
funCheckPods
funCheckImageAndLog
funCheckAlertmanager
funCheckPrometheus
funCheckGrafana
funCheckTargetDown
funCheckx509
funCheckdeadline
