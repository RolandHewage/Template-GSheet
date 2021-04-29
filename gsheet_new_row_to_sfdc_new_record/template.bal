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

        // Customize based on the record type you are willing to create.
        json accountRecord = {};

        if (newValues is (int|string|float)[][]) {
            accountRecord = {
                Name: newValues[0][0].toString(),
                Site: newValues[0][1].toString(),
                BillingCity: newValues[0][2].toString(),
                Phone: newValues[0][3].toString(),
                Industry: newValues[0][4].toString()               
            };
        }

        log:printInfo("SalesforceClient -> createRecord()");
        // Select the record type to create. Here we have created an account record type.
        string|sfdc:Error createdRecord = sfdcClient->createRecord("Account", accountRecord);

        if (createdRecord is string) {
            log:printInfo("Record created successfully. Record ID : " + createdRecord);
        } else {
            log:printError(msg = createdRecord.toString());
        }
    }
}
