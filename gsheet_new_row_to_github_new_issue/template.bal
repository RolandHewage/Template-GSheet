import ballerina/http;
import ballerina/log;
import ballerina/regex;
import ballerinax/github;
import ballerinax/googleapis_drive as drive;
import ballerinax/googleapis_sheets.'listener as sheetsListener;

// Github client configuration parameters
configurable string githubAccessToken = ?;

github:GitHubConfiguration gitHubConfig = {
    accessToken: githubAccessToken
};

// Initialize the Github Client
github:Client githubClient = new (gitHubConfig);

// Google sheets listener configuration parameters
configurable int port = ?;
configurable string callbackURL = ?;
configurable http:OAuth2DirectTokenConfig & readonly driveDirectTokenConfig = ?;

drive:Configuration clientConfiguration = {
    clientConfig: driveDirectTokenConfig
};

# Google sheets listener Event Trigger class
public class EventTrigger {
    public isolated function onNewSheetCreatedEvent(string fileId) {}

    public isolated function onSheetDeletedEvent(string fileId) {}

    public isolated function onFileUpdateEvent(string fileId) {}
}

sheetsListener:SheetListenerConfiguration congifuration = {
    port: port,
    callbackURL: callbackURL,
    driveClientConfiguration: clientConfiguration,
    eventService: new EventTrigger()
};

// Initialize the Google sheets Listener
listener sheetsListener:GoogleSheetEventListener gSheetListener = new (congifuration);

service / on gSheetListener {
    resource function post onEdit (http:Caller caller, http:Request request) returns error? {
        sheetsListener:EventInfo eventInfo = check gSheetListener.getOnEditEventType(caller, request);
        if (eventInfo?.eventType == sheetsListener:APPEND_ROW && eventInfo?.editEventInfo != ()) {
            // Write your logic here.....
            log:print("appendRow() -> GSheetListener");
            log:print("Spreadsheet new row info: " + eventInfo?.editEventInfo.toString());
            (int|string|float)[][]? newValues = eventInfo?.editEventInfo["newValues"];

            string repositoryOwner = "";
            string repositoryName = "";
            string issueTitle = "";
            string issueContent = "";
            string[] issueLabelList = [];
            string[] issueAssigneeList = [];

            if (newValues is (int|string|float)[][]) {
                repositoryOwner = newValues[0][0].toString();
                repositoryName = newValues[0][1].toString();
                issueTitle = newValues[0][2].toString();
                issueContent = newValues[0][3].toString();
                string commaSeparatedLabelList = newValues[0][4].toString();
                string[] labelList = regex:split(commaSeparatedLabelList, ",");
                foreach var label in labelList {
                    issueLabelList.push(label.trim());
                }
                string commaSeparatedAssigneeList = newValues[0][5].toString();
                string[] assigneeList = regex:split(commaSeparatedAssigneeList, ",");
                foreach var assignee in assigneeList {
                    issueAssigneeList.push(assignee.trim());
                }
            }

            log:print("GithubClient -> createIssue()");
            var createdIssue = githubClient->createIssue(repositoryOwner, repositoryName,
                issueTitle, issueContent, issueLabelList, issueAssigneeList);
            
            if (createdIssue is github:Issue) {
                log:print("Created Issue: " + createdIssue.toString());
            } else {
                log:printError("Error: " + createdIssue.toString());
            }
        }
    }
}
