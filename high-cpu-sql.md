Analyzing high CPU usage in Application Tier during Search Indexing
Original Post: 9/11/2017 5:53:57 AM


Search indexer jobs internally go through Crawl, Parse and Feed phases to index TFS artifacts (Code and Work Item). The Parser phase is typically CPU intensive. Also, disk I/Os for internal object store manipulations for the artifacts could contribute to good portion of CPU cycles. However, the indexer jobs are configured to run as low priority jobs so that they do not interfere with the "more essential" Application Tier (AT) jobs such as Build, Version Control, etc. In addition, Search indexer has a built-in throttling mechanism to limit the number of parallel indexer jobs running in a AT when the CPU utilization spikes up. The good part is that this throttling parameters are configurable (as explained in the details below).

In this post, I will go through a sequence of steps to analyze such scenarios and react to it.

Issue symptoms:
Indexing has been in progress for quite some duration.
The CPU is consistently high (above 90%) over a continuous duration while indexing is in progress. The duration would be anything beyond 30-45min. If you observe CPU spikes for short durations and they settle down, that could be expected in certain environments.
There are following steps to this guidance:
Verify the AT machine configuration
Verify whether the CPU spike is indeed caused by Search feature
Potential mitigation
Contacting CSS/PG team with additional data
Verify the AT machine configuration

Check for the recommended H/W configuration here: https://www.visualstudio.com/en-us/docs/search/code/administration

Verify whether the CPU spike is indeed caused by Search feature

IMPORTANT NOTE: The following steps need to be executed while the CPU usage is consistently high (>90%) to get the correct data. It won’t be useful to run these when the CPU usage is in steady state. So it would be best to capture this data when the CPU usage is staying constantly high for say 30-45min.
Check the TfsJobAgent.exe process CPU usage in the TaskMgr. Is it taking close to 100% CPU, or are there other processes that are contributing to CPU usage?

Note, Search is just one part of this TfsJogAgent.exe process. It would be taking up few threads, but there could be other TFS tasks being executed in parallel too. So to confirm if it's a Search issue, let's get to next step

#### Check the number of parallel Search indexer jobs running in that particular AT
```
Query 1:
SELECT [ProcessId]
FROM [Tfs_Configuration].[dbo].[tbl_ServiceHostProcess]
WHERE MachineName = <ATMachineNameWhereTheCpuIsHigh>
and ProcessName = 'TfsJobAgent.exe'
```

```
Query 2:
SELECT [AssociatedJobId]
FROM [<CollectionDB>].[Search].[tbl_IndexingUnit]
WHERE PartitionId > 0 
and (IndexingUnitType = 'Git_Repository' or IndexingUnitType = 'TFVC_Repository')
// Note: If there are multiple collections, then run this query against each of the collection DBs and combine all the
// AssociatedJobId results. Use this list of AssociatedJobIds in Query 3.
```

```
Query 3:
SELECT count(*)
FROM [Tfs_Configuration].[dbo].[tbl_JobQueue]
WHERE [AgentId] = '<ProcessIdObtainedFromQuery1>'
and [JobId] in ('ListOfAssociatedJobIdsObtainedFromQuery2')
and JobState = 1
```


The final output from Query 3 should be a small number (max. 2 or 3). If yes, then the Search throttling logic is executing correctly. If no, then please send this data to the CSS/PG team to investigate it further.
Use perfview tool to get the CPU usage breakdown
  Download perfview from this location. Check a quick guidance here on how to monitor CPU usage. Detailed guidance is there in the perfview app itself.

           - Essentially, you need to kick start a collect for a short interval, say 5-10 min.


           - Ensure the CPU samples option is checked.


           - Start Collection. Run it for 5-10 min. Then stop the collection. It will generate a .etl file
           - To analyze the .etl file,

                 # Open the Processes report to see which process is having max. percentage of  CPU utilization



                 # If it is the TfsJobAgent.exe process that has the max. percentage of CPU usage, then open the CPU stacks.



                   # Select and open the TfsJobAgent.exe process


                   # Check for stack window for this process, check which all stack frames are taking maximum CPU time.

You can engage the CSS/PG team at this moment, or just send the .etl file offline to analyze

#### Potential Mitigation
You can try a couple of things to have a quick mitigation of the environment (again these mitigations are assuming the CPU spike happened because of Search only)
Update the CPU throttle configurations for Search in the TFS Configuration DB

```
You should see 2 entries:
SELECT *
FROM [Tfs_Configuration].[dbo].[tbl_RegistryItems]
WHERE PartitionId > 0 and
(ChildItem = 'JobQueueControllerCpuHealthJobThrottleCount\' or ChildItem = 'JobQueueControllerCpuHealthThreshold\')
PartitionId ParentPath ChildItem RegValue
1 #\Service\ALMSearch\Settings\ JobQueueControllerCpuHealthJobThrottleCount\ 2
1 #\Service\ALMSearch\Settings\ JobQueueControllerCpuHealthThreshold\ 90
```

Basically this configuration means, if the CPU is staying high above 90% usage, allow not more than 2 Search indexer jobs to run in parallel.
Update them to values –

JobQueueControllerCpuHealthJobThrottleCount = 1 and
JobQueueControllerCpuHealthThreshold = 70 (or anything lesser you feel should be a stable CPU usage)

Run these 2 scripts in TFS Configuration DB:

```
declare @registryValue dbo.typ_KeyValuePairStringTableNullable
insert into @registryValue values('#\Service\ALMSearch\SettingsJobQueueControllerCpuHealthJobThrottleCount\', '1')
exec prc_UpdateRegistry @partitionId=1, @identityName = '00000000-0000-0000-0000-000000000000', @registryUpdates = @registryValue
```

```
declare @registryValue dbo.typ_KeyValuePairStringTableNullable
insert into @registryValue values('#\Service\ALMSearch\Settings\JobQueueControllerCpuHealthThreshold\', '70')
exec prc_UpdateRegistry @partitionId=1, @identityName = '00000000-0000-0000-0000-000000000000', @registryUpdates = @registryValue
Note, these settings will slow down the indexing; this slow down happens though only when CPU in the AT machine is high. If the CPU is stable, the throttling won't apply unnecessarily and jobs will run as normal.
```

If throttling is kicking in, you will see ResultMessage like "Marking {X} events back to Pending state with requeueDelay 0sec as the IP state is not healthy. Job ID {Guid}". You can run a query to check for that:

``` 
 SELECT TOP (100)
                [JobSource],
                [JobId],
                [StartTime],
                [EndTime],
                [Result],
                [ResultMessage]
              FROM [Tfs_Configuration].[dbo].[tbl_JobHistory]
              WHERE ResultMessage like '%back to Pending state with requeueDelay%'
              ORDER BY StartTime desc
              
```              
Observe the AT machine post the above step. If still the CPU stays high of a longer time (say 30-45min), just pause the indexing temporarily using this script.

Contacting CSS/PG team with additional data
While contacting the PG team,
Provide all of the information above, including the etl files, etc.
Provide information on the approximate code/repository volume in the collections (# Collections, # Repositories, Overall Code size per Collection)
Provide the information on the job history

```
SELECT [JobSource]
  ,[JobId]
  ,[StartTime]
  ,[EndTime]
  ,[Result]
  ,[ResultMessage]
FROM [Tfs_Configuration].[dbo].[tbl_JobHistory]
WHERE (ResultMessage like '%completed with status%'
  or ResultMessage like '%back to Pending state with requeueDelay%'
  or ResultMessage like '%Installed extension%')
  and StartTime > '<Some time where you first seeing CPU spikes>'
  and StartTime < '<Time till which CPU spike was consistently observed, or the present time if still CPU is high'
ORDER BY StartTime desc

```

Try to provide the job results for a limited time duration, else it becomes too much data to open and analyze.
