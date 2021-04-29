import ballerina/log;
import ballerina/regex;
import ballerinax/github;
import ballerinax/googleapis_sheets.'listener as sheetsListener;

// Github client configuration parameters
configurable string githubAccessToken = ?;

github:Configuration gitHubConfig = {
    accessToken: githubAccessToken
};

// Initialize the Github Client
github:Client githubClient = new (gitHubConfig);

// Google sheets listener configuration parameters
configurable int port = ?;
configurable string spreadsheetId = ?;

sheetsListener:SheetListenerConfiguration congifuration = {
    port: port,
    spreadsheetId: spreadsheetId
};

// Initialize the Google sheets Listener
listener sheetsListener:Listener gSheetListener = new (congifuration);

service / on gSheetListener {
    remote function onAppendRow(sheetsListener:GSheetEvent event) returns error? {
        log:printInfo("appendRow() -> GSheetListener");
        log:printInfo("Spreadsheet new row info: " + event?.eventInfo.toString());
        (int|string|float)[][]? newValues = event?.eventInfo["newValues"];

        string repositoryOwner = "";
        string repositoryName = "";
        string[] issueLabelList = [];
        string[] issueAssigneeList = [];

        if (newValues is (int|string|float)[][]) {
            repositoryOwner = newValues[0][0].toString();
            repositoryName = newValues[0][1].toString();
            string commaSeparatedLabelList = newValues[0][4].toString();
            string[] labelList = regex:split(commaSeparatedLabelList, ",");
            foreach var label in labelList {
                var labelIdResponse = githubClient->getRepositoryLabel(repositoryOwner, repositoryName, label.trim());
                if (labelIdResponse is github:Label) {
                    issueLabelList.push(labelIdResponse.id);
                } else {
                    log:printError("Error: " + labelIdResponse.toString());
                }         
            }
            string commaSeparatedAssigneeList = newValues[0][5].toString();
            string[] assigneeList = regex:split(commaSeparatedAssigneeList, ",");
            foreach var assignee in assigneeList {
                var assigneeIdResponse = githubClient->getUserId(assignee.trim());
                if (assigneeIdResponse is string) {
                    issueAssigneeList.push(assigneeIdResponse);
                } else {
                    log:printError("Error: " + assigneeIdResponse.toString());
                }           
            }
            github:CreateIssueInput createIssueInput = {
                title: newValues[0][2].toString(),
                body: newValues[0][3].toString(),
                labelIds: issueLabelList,
                assigneeIds: issueAssigneeList
            };
            log:printInfo("GithubClient -> createIssue()");
            var createdIssue = githubClient->createIssue(createIssueInput, repositoryOwner, repositoryName);
            if (createdIssue is github:Issue) {
                log:printInfo("Created Issue: " + createdIssue.toString());
            } else {
                log:printError("Error: " + createdIssue.toString());
            }
        } else {
            log:printError("Error: Empty row appended");
        } 
    }
}
