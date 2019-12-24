$collection = "http://localhost:8080/tfs/DefaultCollection" # change this to the URL of your team project collection
$pathToAss2 = "C:\Program Files\Microsoft Team Foundation Server 2018\Tools"
$pathToAss4 = "C:\Program Files\Microsoft Team Foundation Server 2018\Tools"
Add-Type -Path "$pathToAss2\Microsoft.TeamFoundation.Client.dll"
Add-Type -Path "$pathToAss2\Microsoft.TeamFoundation.Common.dll"
Add-Type -Path "$pathToAss2\Microsoft.TeamFoundation.WorkItemTracking.Client.dll"
Add-Type -Path "$pathToAss2\Microsoft.TeamFoundation.VersionControl.Client.dll"
#Add-Type -Path "$pathToAss4\Microsoft.TeamFoundation.ProjectManagement.dll"
$tpc =  [Microsoft.TeamFoundation.Client.TfsTeamProjectCollectionFactory]::GetTeamProjectCollection($collection)
$jobService = $tpc.GetService([Microsoft.TeamFoundation.Framework.Client.ITeamFoundationJobService])

# job name, change to right job name
$job = $jobService.QueryJobs() | Where-Object {$_.Name -eq "Work Item Tracking Integration Synchronization4444"}
$job
$jobService.QueryLatestJobHistory([Guid[]] @($job.JobId))

#set interval
$interval = 10801 # change this to the number of seconds between each run; 172800 = 2 days
$job.Schedule[0].Interval = $interval # there is only one schedule for the build information clean-up job, we set its interval

#disable job （ Enabled：0 ， SchedulesDisabled：1 ，FullyDisabled：2）
$job.EnabledState=2   
$jobService.UpdateJob($job)
