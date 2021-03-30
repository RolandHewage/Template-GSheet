import ballerina/http;
import ballerina/log;
import ballerinax/sfdc;
import ballerinax/googleapis_drive as drive;
import ballerinax/googleapis_sheets.'listener as sheetsListener;

// Salesforce client configuration parameters
configurable string ep_url = ?;
configurable http:OAuth2DirectTokenConfig & readonly sfdcDirectTokenConfig = ?;

sfdc:SalesforceConfiguration sfConfig = {
    baseUrl: ep_url,
    clientConfig: sfdcDirectTokenConfig
};

// Initialize the Salesforce Client
sfdc:BaseClient sfdcClient = check new (sfConfig);

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

            log:print("SalesforceClient -> createRecord()");
            // Select the record type to create. Here we have created an account record type.
            string|sfdc:Error createdRecord = sfdcClient->createRecord("Account", accountRecord);

            if (createdRecord is string) {
                log:print("Record created successfully. Record ID : " + createdRecord);
            } else {
                log:printError(msg = createdRecord.toString());
            }
        }
    }
}
