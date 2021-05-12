import ballerina/http;
import ballerina/log;
import ballerina/regex;
import ballerinax/sfdc;
import ballerinax/googleapis.sheets as sheets;
import ballerinax/googleapis.sheets.'listener as sheetsListener;

// Constants
const string INTEGER_REGEX = "\\d+";

// Salesforce client configuration parameters
@display { kind: "OAuthConfig", provider: "Salesforce", label: "Setup Salesforce connection" }
configurable http:OAuth2RefreshTokenGrantConfig & readonly sfdcOAuthConfig = ?;
@display { label: "EndPoint URL" }
configurable string epURL = ?;

sfdc:SalesforceConfiguration sfdcConfig = {
    baseUrl: epURL,
    clientConfig: sfdcOAuthConfig
};

// Google sheets client configuration parameters
@display { kind: "OAuthConfig", provider: "Google Sheets", label: "Setup GSheets connection" }
configurable http:OAuth2RefreshTokenGrantConfig & readonly sheetsOAuthConfig = ?;
@display { kind: "ConnectionField", connectionRef: "sheetsOAuthConfig", provider: "Google Sheets", operationName: "getAllSpreadsheets", label: "Spread sheet name"}
configurable string spreadsheetId = ?;
@display { kind: "ConnectionField", connectionRef: "sheetsOAuthConfig", argRef: "spreadsheetId", provider: "Google Sheets", operationName: "getSheetList", label: "Work Sheet Name"}
configurable string worksheetName = ?;

sheets:SpreadsheetConfiguration spreadsheetConfig = {
    oauthClientConfig: sheetsOAuthConfig
};

// Google sheets listener configuration parameters
configurable int port = ?;

sheetsListener:SheetListenerConfiguration sheetListenerConfig = {
    port: port,
    spreadsheetId: spreadsheetId
};

// Initialize the Salesforce Client
sfdc:Client sfdcClient = check new (sfdcConfig);

// Initialize Google sheets client 
sheets:Client spreadsheetClient = check new (spreadsheetConfig);

// Initialize the Google sheets Listener
listener sheetsListener:Listener gSheetListener = new (sheetListenerConfig);

service / on gSheetListener {
    remote function onAppendRow(sheetsListener:GSheetEvent event) returns error? {
        // Write your logic here.....
        log:printInfo("appendRow() -> GSheetListener");
        log:printInfo("Spreadsheet new row info: " + event?.eventInfo.toString());

        // Get the appended range
        string? rangeUpdated = event?.eventInfo["rangeUpdated"];
        // Get the appended column headings 
        (int|string|float)[][]? appendedColumnHeadings = ();
        if (rangeUpdated is string) {
            string a1Notation = getA1NotationForAppendedColumnHeadings(rangeUpdated);
            sheets:Range appendedColumnHeadingsResult = check spreadsheetClient->getRange(spreadsheetId, 
                worksheetName, a1Notation);
            appendedColumnHeadings = appendedColumnHeadingsResult.values;
        }
        // Get the appended values 
        (int|string|float)[][]? appendedValues = event?.eventInfo["newValues"];

        if (appendedValues is (int|string|float)[][] && appendedColumnHeadings is (int|string|float)[][]) {
            json leadRecord = createJsonRecord(appendedColumnHeadings[0], appendedValues[0]);
            log:printInfo("SalesforceClient -> createLead()");
            string|sfdc:Error createdLead = sfdcClient->createLead(leadRecord);

            if (createdLead is string) {
                log:printInfo("Lead Created Successfully. Lead ID : " + createdLead);
            } else {
                log:printError(msg = createdLead.message());
            }   
        }
    }
}

isolated function getA1NotationForAppendedColumnHeadings(string rangeUpdated) returns string {
    return regex:replaceAll(rangeUpdated, INTEGER_REGEX, "1");
}

isolated function createJsonRecord((int|string|float)[] columnNames, (string|int|float)[] values) returns map<json> {
    map<json> jsonMap = {};
    foreach int index in 0 ..< columnNames.length() {
            jsonMap[columnNames[index].toString()] = values[index];
    }
    return jsonMap;
}
