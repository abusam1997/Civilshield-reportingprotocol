# CivicShield - Crime Reporting Protocol (CCRP)

A decentralized protocol for submitting, managing, and tracking crime reports on the Stacks blockchain.

## Features

- **Report Submission:** Anyone can submit a crime report with optional anonymity and off-chain proof.
- **Agency Management:** Contract owner can register/unregister agencies to manage reports.
- **Status Updates:** Approved agencies can update the status of reports.
- **Duplicate Voting:** Community can flag duplicate reports (one vote per user per report).
- **Public Views:** Read-only functions to view reports, duplicate counts, and report statistics.

## Contract Overview

- **Contract Owner:** Set at deployment; manages agency registration.
- **Crime Reports:** Each report includes reporter, category, description, location, optional proof hash, status, and timestamp.
- **Agencies:** Registered agencies can update report statuses.
- **Duplicate Votes:** Prevents double voting on duplicate flags.

## Key Functions

### Agency Management

- `register-agency(agency)`  
  Register a new agency (owner only).

- `unregister-agency(agency)`  
  Remove an agency (owner only).

### Reporting

- `submit-report(category, description, location, proof-hash, anonymous)`  
  Submit a new crime report.

- `update-status(report-id, new-status)`  
  Update the status of a report (agency only).

### Duplicate Voting

- `vote-duplicate(report-id)`  
  Flag a report as duplicate (one vote per user per report).

### Read-only Views

- `get-report(report-id)`  
  View report details (reporter masked unless authorized).

- `get-duplicate-count(report-id)`  
  Get duplicate vote count for a report.

- `get-report-count()`  
  Get total number of reports.

- `get-report-id-by-index(index)`  
  Get report ID by index.

## Events

Events are logged using `print` statements for:

- Agency registration
- Report submission
- Status updates
- Duplicate votes

## Error Codes

- `401` - Not authorized
- `402` - Already registered
- `404` - Not found
- `409` - Already voted
- `410` - Invalid input

## Usage

Deploy the contract on the Stacks blockchain. Interact using Clarity calls via your preferred Stacks wallet or development tools.

## License

MIT
