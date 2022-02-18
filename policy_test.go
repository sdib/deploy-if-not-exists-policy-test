package test

import (
	"context"
	"fmt"
	"testing"
	"time"

	"github.com/Azure/azure-sdk-for-go/profiles/2019-03-01/resources/mgmt/insights"
	"github.com/gruntwork-io/terratest/modules/azure"
	"github.com/gruntwork-io/terratest/modules/logger"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func TestDeployIfNotExistsKvDiagSettings(t *testing.T) {
	t.Parallel()

	// Arrange
	beforeAllOptions := &terraform.Options{
		TerraformDir: "./fixtures/beforeAll",
		Logger:       logger.Discard,
	}

	defer terraform.Destroy(t, beforeAllOptions)
	terraform.InitAndApply(t, beforeAllOptions)
	resourceGroupName := terraform.Output(t, beforeAllOptions, "resource_group_name")
	tfOptions := &terraform.Options{
		TerraformDir: "./fixtures",
		Vars: map[string]interface{}{
			"resource_group_name": resourceGroupName,
		},
		Logger: logger.Discard,
	}

	// Act
	defer terraform.Destroy(t, tfOptions)
	terraform.InitAndApply(t, tfOptions)
	subscriptionID := terraform.Output(t, tfOptions, "subscription_id")
	vaultID := terraform.Output(t, tfOptions, "vault_id")

	// Waiting for evaluation delay + template deployment delay
	// as per https://docs.microsoft.com/en-us/azure/governance/policy/concepts/effects#deployifnotexists
	time.Sleep(12 * time.Minute)

	// Assert
	settings, err := getDiagnosticSettings(subscriptionID, vaultID, "AutoTestDiagnosticSetting")
	require.NoError(t, err, "failed to get the key vault diagnostic settings")

	for _, logsConfig := range *settings.DiagnosticSettings.Logs {
		if *logsConfig.Category == "AuditEvent" {
			assert.Truef(t, *logsConfig.Enabled, "AuditEvent should be enabled.")
		} else {
			assert.Falsef(t, *logsConfig.Enabled, "%s should not be enabled.", *logsConfig.Category)
		}
	}

	for _, metricConfig := range *settings.DiagnosticSettings.Metrics {
		assert.Falsef(t, *metricConfig.Enabled, "%s should not be enabled.", *metricConfig.Category)
	}
}

func getDiagnosticSettings(subscriptionID, resourceID, diagSettingsName string) (*insights.DiagnosticSettingsResource, error) {
	auth, err := azure.NewAuthorizer()
	if err != nil {
		return nil, fmt.Errorf("authentication failed")
	}
	client := insights.NewDiagnosticSettingsClient(subscriptionID)
	client.Authorizer = *auth
	client.AddToUserAgent("testing-agent")

	ctx := context.Background()
	settings, err := client.Get(ctx, resourceID, diagSettingsName)
	if err != nil {
		return nil, fmt.Errorf("error when trying to get diagnostic setting '%s' on resource with id '%s'. %v", diagSettingsName, resourceID, err)
	}

	return &settings, nil
}
