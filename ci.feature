Feature: Install and configuration related scenarios
  # @author juzhao@redhat.com
  # @case_id OCP-26041
  @admin
  Scenario: cookie_secure is true in grafana route	
    Given the master version >= "4.3"
    Given I switch to the first user
    And the first user is cluster-admin
    And I use the "openshift-monitoring" project

    Given a pod becomes ready with labels:
      | app=grafana |
    When I run commands on the host:
      | oc -n openshift-monitoring get secret grafana-config -o jsonpath="{.data.grafana\.ini}" | base64 -d | grep cookie_secure |
    Then the step should succeed
    And the output should contain:
      | cookie_secure = true |


  # @author juzhao@redhat.com
  # @case_id OCP-23705
  @admin
  Scenario: cluster-version-operator/kube-apiserver/kube-controller-manager/kube-scheduler/openshift-apiserver ServiceMonitors are moved out of cluster-monitoring-operator	
    Given the master version >= "4.2"
    Given I switch to the first user
    And the first user is cluster-admin
    And I use the "openshift-monitoring" project

    When I run the :get client command with:
      | resource | ServiceMonitor |
    Then the output should not contain:
      | cluster-version-operator |
      | kube-apiserver |
      | kube-controller-manager |
      | kube-scheduler |
      | openshift-apiserver |
