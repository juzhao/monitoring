Feature: Query Browser related scenarios
  # @author juzhao@redhat.com
  # @case_id OCP-21199
  @admin
  Scenario: Edit Alertmanager Silence - Invalid matcher
    Given I switch to the first user
    And the first user is cluster-admin
    Given I open admin console in a browser
    Then the step should succeed
