# Azure DevOps Server 2025 - Elasticsearch 8.14 Scripts

This folder contains PowerShell scripts for managing and troubleshooting search functionality in Azure DevOps Server 2025 with Elasticsearch 8.14.

## Prerequisites

- **Administrative Access**: Many scripts require administrator privileges
- **SQL Server PowerShell Module**: SQLSERVER or SQLPS module must be installed
- **Network Access**: Access to SQL Server instance and Elasticsearch service
- **Azure DevOps Server 2025**: These scripts are specifically designed for ADO Server 2025

## Quick Reference Guide

### 🔍 **Troubleshooting & Diagnostics**

| Script | Purpose | When to Use |
|--------|---------|-------------|
| `Troubleshooting\Repair-Search.ps1` | **Primary troubleshooting tool** | Search not working, automated problem detection |
| `SearchDiagnostics\ElasticsearchDiagnostics.ps1` | Collect Elasticsearch diagnostics | Before contacting support |
| `SearchDiagnostics\ConfigurationDBSearchDiagnostics.ps1` | Configuration DB diagnostics | Configuration-related issues |
| `SearchDiagnostics\CollectionDBSearchDiagnostics.ps1` | Collection DB diagnostics | Collection-specific issues |

### ⚙️ **Indexing Management**

| Script | Purpose | When to Use |
|--------|---------|-------------|
| `TriggerCollectionIndexing.ps1` | Start indexing for a collection | After setup, search not working |
| `Re-IndexingCodeRepository.ps1` | Re-index specific repository | Single repository issues |
| `PauseIndexing.ps1` | Temporarily stop indexing | During maintenance |
| `ResumeIndexing.ps1` | Resume paused indexing | After maintenance complete |

### 🛠️ **Maintenance & Optimization**

| Script | Purpose | When to Use |
|--------|---------|-------------|
| `OptimizeElasticIndex.ps1` | Optimize Elasticsearch indices | Performance issues, disk space cleanup |
| `WipeOutAndResetElasticSearch.ps1` | **Complete reset** (destructive) | Last resort, corrupted installation |

### 📊 **Monitoring & Status**

| Script | Purpose | When to Use |
|--------|---------|-------------|
| `GetElasticsearchDocCountPerRepository.ps1` | Get document counts per repository | Monitor indexing progress |
| `ExtensionInstallIndexingStatus.ps1` | Check indexing status | Monitor collection indexing |
| `RecentIndexingActivity.ps1` | View recent indexing activity | Check indexing progress |

## Common Usage Scenarios

### 🚨 **Search is not working at all**
1. Run `Troubleshooting\Repair-Search.ps1` first (automated diagnosis)
2. If issues persist, run diagnostics and contact support

### 🔄 **Need to re-index everything**
```powershell
.\TriggerCollectionIndexing.ps1 -SQLServerInstance "." -CollectionDatabaseName "AzureDevOps_DefaultCollection" -ConfigurationDatabaseName "AzureDevOps_Configuration" -CollectionName "DefaultCollection" -EntityType "All"
```

### 🎯 **Single repository not searchable**
```powershell
.\Re-IndexingCodeRepository.ps1 -SQLServerInstance "." -CollectionDatabaseName "AzureDevOps_DefaultCollection" -ConfigurationDatabaseName "AzureDevOps_Configuration" -IndexingUnitType "Git_Repository" -CollectionName "DefaultCollection" -RepositoryName "MyProject"
```

### 🚧 **Maintenance mode**
```powershell
# Before maintenance
.\PauseIndexing.ps1 -SQLServerInstance "." -ConfigurationDatabaseName "AzureDevOps_Configuration"

# After maintenance
.\ResumeIndexing.ps1 -SQLServerInstance "." -ConfigurationDatabaseName "AzureDevOps_Configuration"
```

### 🧹 **Performance optimization**
```powershell
.\OptimizeElasticIndex.ps1 -ElasticServerUrl "http://localhost:9200" -IndexName "code*"
```

## Parameter Reference

### Common Parameters
- **SQLServerInstance**: SQL Server instance name
  - Local: `"."` or `"localhost"`
  - Named instance: `"ServerName\InstanceName"`
  - Port: `"ServerName,1433"`

- **ConfigurationDatabaseName**: Usually `"AzureDevOps_Configuration"`
- **CollectionDatabaseName**: Usually `"AzureDevOps_DefaultCollection"` or `"AzureDevOps_YourCollectionName"`
- **CollectionName**: Collection name as shown in Admin Console (e.g., `"DefaultCollection"`)
- **EntityType**: `"All"`, `"Code"`, `"WorkItem"`, or `"Wiki"`
- **ElasticsearchServiceUrl**: Elasticsearch URL with protocol and port (e.g., `"http://localhost:9200"`)

## Getting Help

1. **Check script help**: Use `Get-Help .\ScriptName.ps1 -Examples`
2. **Review logs**: Most scripts create log files with detailed information
3. **Check Azure DevOps Server logs**: Located in `%ProgramData%\Microsoft\Azure DevOps\Server Configuration\Logs`
4. **Elasticsearch logs**: Located in Elasticsearch installation `\logs` folder

## Support

For issues not resolved by these scripts:
1. Run diagnostics scripts to collect data
2. Check [Azure DevOps Server documentation](https://docs.microsoft.com/azure/devops/server/)
3. Report issues at [Developer Community](https://developercommunity.visualstudio.com/spaces/22/)

---
**⚠️ Important**: Always test scripts in a non-production environment first. Some scripts can impact search performance or require re-indexing.
