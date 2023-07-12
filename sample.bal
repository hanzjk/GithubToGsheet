import ballerina/http;
import ballerina/log;
import ballerinax/googleapis.sheets as sheets;
import ballerinax/trigger.github;
import wso2/choreo.sendemail as email;

// Types
type OAuth2RefreshTokenGrantConfig record {
    string clientId;
    string clientSecret;
    string refreshToken;
    string refreshUrl = "https://www.googleapis.com/oauth2/v3/token";
};

// Constants
const HEADINGS_ROW = 1;

final string[] & readonly columnNames = [
    "Issue Link",
    "Issue Number",
    "Issue Title",
    "Issue Creator",
    "Issue Created At"
];

// Github configuration parameters
configurable github:ListenerConfig gitHubListenerConfig = ?;

// Google sheets configuration parameters
configurable OAuth2RefreshTokenGrantConfig GSheetAuthConfig = ?;
configurable string spreadsheetId = ?;
configurable string worksheetName = ?;

listener http:Listener httpListener = new(8090);
listener github:Listener gitHubListener = new (gitHubListenerConfig, httpListener);

 string recipientAddress = "hansijayanika@gmail.com";

@display { label: "GitHub New Issue to Google Sheets Row" }
service github:IssuesService on gitHubListener {
    remote function onAssigned(github:IssuesEvent payload) returns error? {
      sheets:Client spreadsheetClient = check new ({
          auth: {
            clientId: GSheetAuthConfig.clientId,
            clientSecret: GSheetAuthConfig.clientSecret,
            refreshToken: GSheetAuthConfig.refreshToken,
            refreshUrl: GSheetAuthConfig.refreshUrl
          }
      });

      sheets:Row existingColumnNames = check spreadsheetClient->getRow(spreadsheetId, worksheetName, HEADINGS_ROW);
      if existingColumnNames.values.length() == 0 {
          check spreadsheetClient->appendRowToSheet(spreadsheetId, worksheetName, columnNames);
      }

      (int|string|decimal)[] values = [payload.issue.html_url, payload.issue.number, payload.issue.title, payload.issue.user.login, payload.issue.created_at];
      check spreadsheetClient->appendRowToSheet(spreadsheetId, worksheetName, values);
      log:printInfo("New GiHub issue assignment record appended to GSheet successfully!");


      email:Client emailClient = check new ();
      string sendEmailResponse = check emailClient->sendEmail(recipientAddress, "New Issue Created", "Issue Title: " + payload.issue.title + " Issue Body: " + payload.issue.html_url);
      log:printInfo("Email sent to " + recipientAddress + " with response: " + sendEmailResponse);

    }
    remote function onOpened(github:IssuesEvent payload ) returns error? {
      return;
    }
    remote function onClosed(github:IssuesEvent payload ) returns error? {
      return;
    }
    remote function onReopened(github:IssuesEvent payload ) returns error? {
      return;
    }
    remote function onUnassigned(github:IssuesEvent payload ) returns error? {
      return;
    }
    remote function onLabeled(github:IssuesEvent payload ) returns error? {
      return;
    }
    remote function onUnlabeled(github:IssuesEvent payload ) returns error? {
      return;
    }
}

service /ignore on httpListener {}
