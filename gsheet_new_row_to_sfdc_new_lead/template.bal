import ballerina/http;
import ballerina/log;
import ballerinax/sfdc;
import ballerinax/googleapis_sheets.'listener as sheetsListener;

// Salesforce client configuration parameters
configurable string ep_url = ?;
configurable http:OAuth2RefreshTokenGrantConfig & readonly sfdcDirectTokenConfig = ?;

sfdc:SalesforceConfiguration sfConfig = {
    baseUrl: ep_url,
    clientConfig: sfdcDirectTokenConfig
};

// Initialize the Salesforce Client
sfdc:Client sfdcClient = check new (sfConfig);

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
        // Write your logic here.....
        log:printInfo("appendRow() -> GSheetListener");
        log:printInfo("Spreadsheet new row info: " + event?.eventInfo.toString());
        (int|string|float)[][]? newValues = event?.eventInfo["newValues"];

        json leadRecord = {};

        if (newValues is (int|string|float)[][]) {
            leadRecord = {
                FirstName: newValues[0][0].toString(),
                LastName: newValues[0][1].toString(),
                Title: newValues[0][2].toString(),
                Company: newValues[0][3].toString(),
                Phone: newValues[0][4].toString(),
                Email: newValues[0][5].toString()
            };
        }

        log:printInfo("SalesforceClient -> createLead()");
        string|sfdc:Error createdLead = sfdcClient->createLead(leadRecord);

        if (createdLead is string) {
            log:printInfo("Lead Created Successfully. Lead ID : " + createdLead);
        } else {
            log:printError(msg = createdLead.message());
        }   
    }
}
