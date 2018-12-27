Feature: Install and uninstall related scenarios
  # @author juzhao@redhat.com
  # @case_id OCP-21774
  @admin
  @destructive
  Scenario: Basic function check for cluster monitoring
    Given the master version >= "3.11"
    Given I switch to the first user
    And the first user is cluster-admin
    And I use the "openshift-monitoring" project

    Given a pod becomes ready with labels:
      | statefulset.kubernetes.io/pod-name=prometheus-k8s-0 |
    Then evaluation of `pod.ip` is stored in the :pod_ip_prometheus clipboard
    When I run commands on the host:
      | curl -k -H "Authorization: Bearer $(oc sa get-token prometheus-k8s -n openshift-monitoring)"  https://<%= cb.pod_ip_prometheus %>:9091/metrics %> |
    Then the step should succeed
    And the output should contain:
      | prometheus_rule_group_interval_seconds |

    Given a pod becomes ready with labels:
      | statefulset.kubernetes.io/pod-name=alertmanager-main-0 |
    Then evaluation of `pod.ip` is stored in the :pod_ip_alertmanager clipboard
    When I run commands on the host:
      | curl -k -H "Authorization: Bearer $(oc sa get-token prometheus-k8s -n openshift-monitoring)"  https://<%= cb.pod_ip_alertmanager %>:9094/api/v1/alerts %> |
    Then the step should succeed
    And the output should contain:
      | DeadMansSwitch |

    Given a pod becomes ready with labels:
      | app=grafana |
    Then evaluation of `pod.ip` is stored in the :pod_ip_grafana clipboard
    When I run commands on the host:
      | curl -k -H "Authorization: Bearer $(oc sa get-token prometheus-k8s -n openshift-monitoring)"  https://<%= cb.pod_ip_grafana %>:3000/api/health %> |
    Then the step should succeed
    And the output should contain:
      | ok |
