import ballerina/log;
import ballerina/regex;
import ballerinax/github;
import ballerinax/googleapis.sheets.'listener as sheetsListener;

// Github client configuration parameters
configurable string githubAccessToken = ?;

github:Configuration gitHubConfig = {
    accessToken: githubAccessToken
};

// Initialize the Github Client
github:Client githubClient = check new (gitHubConfig);

// Google sheets listener configuration parameters
configurable int port = ?;
@display { kind: "ConnectionField", connectionRef: "sheetsOAuthConfig", provider: "Google Sheets", operationName: "getAllSpreadsheets", label: "Spread sheet name"}
configurable string spreadsheetId = ?;
@display { kind: "ConnectionField", connectionRef: "sheetsOAuthConfig", argRef: "spreadsheetId", provider: "Google Sheets", operationName: "getSheetList", label: "Work Sheet Name"}
configurable string worksheetName = ?;

sheetsListener:SheetListenerConfiguration congifuration = {
    port: port,
    spreadsheetId: spreadsheetId
};

// Initialize the Google sheets Listener
listener sheetsListener:Listener gSheetListener = new (congifuration);

service / on gSheetListener {
    remote function onAppendRow(sheetsListener:GSheetEvent event) returns error? {
        if (event?.eventInfo?.worksheetName == worksheetName) {
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
                        log:printError(msg = labelIdResponse.toString());
                    }         
                }
                string commaSeparatedAssigneeList = newValues[0][5].toString();
                string[] assigneeList = regex:split(commaSeparatedAssigneeList, ",");
                foreach var assignee in assigneeList {
                    var assigneeIdResponse = githubClient->getUserId(assignee.trim());
                    if (assigneeIdResponse is string) {
                        issueAssigneeList.push(assigneeIdResponse);
                    } else {
                        log:printError(msg = assigneeIdResponse.toString());
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
                    log:printInfo("Issue Created Successfully. Issue ID: " + createdIssue.id.toString());
                } else {
                    log:printError(msg = createdIssue.toString());
                }
            } else {
                log:printError("Empty row appended");
            } 
        } else {
            log:printError("Event received was not from the configured worksheet");
        }
    }
}
