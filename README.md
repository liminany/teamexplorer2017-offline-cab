## sql server 监控/调优资料

https://blog.csdn.net/g394100942/article/details/78622696

https://github.com/liminany/teamexplorer2017-offline-cab/releases/tag/TFS-WorkItem-add

## sql 格式化插件

http://www.dpriver.com/dlaction.php

## 存储优化实践
https://mp.weixin.qq.com/s/x71CLB-rQaomtAplX8oo5g

## Clean up your Team Project Collection prior to migrating to VSTS

https://jessehouwing.net/tfs-clean-up-your-project-collection/

https://developercommunity.visualstudio.com/content/problem/63712/tfs-database-size.html



## Performing a clean uninstall of Search extensions in Team Foundation Server 

https://tapas-techsnips.blogspot.com/2019/01/performing-clean-uninstall-of-search.html


```
declare @features dbo.typ_KeyValuePairStringTableNullable
insert into @features values('#\FeatureAvailability\Entries\Search.Server.FaultManagement\', '0')
exec prc_UpdateRegistry @partitionId=1, @identityName = '00000000-0000-0000-0000-000000000000', @registryUpdates = @features
```

The extension uninstall triggers a sequence of clean up jobs per repository under that collection to delete the indices. In the [Tfs_Configuration].[dbo].[tbl_JobHistory] table, you can see delete jobs cleaning up the ES documents. There will be one job result entry for each repository in that collection.

```
SELECT [JobId], [StartTime], [Result], [ResultMessage]
FROM [Tfs_Configuration].[dbo].[tbl_JobHistory] as History
INNER JOIN
[Tfs_Configuration].[dbo].[tbl_ServiceHost] as ServiceHost
ON History.JobSource = ServiceHost.HostId
WHERE ResultMessage like '%Delete-SearchExtensionEventNotification%'
ORDER BY StartTime desc
```

Ensure all IndexingUnits and ChangeEvents for that entity in the Collection DB are cleaned up (run the scripts in the following sequence only)

```
DELETE FROM [Search].[tbl_IndexingUnitChangeEvent]
WHERE IndexingUnitId in
(
    SELECT IndexingUnitId FROM [Search].[tbl_IndexingUnit] WHERE EntityType = '%EntityType%' 
)
DELETE FROM [Search].[tbl_IndexingUnit] where EntityType = '%EntityType%'
(where, %EntityType% would be 'Code',  'WorkItem' or 'WIKI' depending on the extension being uninstalled)
```

Enable back the FaultManagement feature by running the following script on Configuration DB:
```
declare @features dbo.typ_KeyValuePairStringTableNullable
insert into @features values('#\FeatureAvailability\Entries\Search.Server.FaultManagement\', '1')
exec prc_UpdateRegistry @partitionId=1, @identityName = '00000000-0000-0000-0000-000000000000', @registryUpdates = @features
```

Verify that the #\Service\ALMSearch\Settings\IsExtensionOperationInProgress\%EntityType%\Uninstalled either does not exist, or is reset correctly to false.

```
SELECT *
FROM [<CollectionDB>].[dbo].[tbl_RegistryItems]
WHERE ParentPath = '#\Service\ALMSearch\Settings\IsExtensionOperationInProgress\%EntityType%\' and ChildItem = 'Uninstalled\'
```
    
If it is set to 'True', execute the following command to reset it:

```
declare @registryValue dbo.typ_KeyValuePairStringTableNullable
insert into @registryValue values('#\Service\ALMSearch\Settings\IsExtensionOperationInProgress\%EntityType%\Uninstalled\', 'False')
exec prc_UpdateRegistry @partitionId=1, @identityName = '00000000-0000-0000-0000-000000000000', @registryUpdates = @registryValue
```









