ZSANCTIONSIO is a template SAP ABAP report that uses the sanctions.io API to check names in the SAP system (vendors, customers, employees, or names in any table:field) against sanction lists.

This report does not implement features like matching country or date of birth, etc. Only names are used for matching.
For full API documentation, go here: https://api-docs.sanctions.io

This report is provided as is and with no warranty under the 3-clause-BSD license, see https://opensource.org/licenses/BSD-3-Clause.
Redistribution and use, with or without modification, is permitted.

Two steps are required to use the data for sanction list screening report:

A – Get an API key from sanctions.io: register for a free trial account at api.sanctions.io, note down the API key provided after registering, and maintain the key in the parameters for this check.

B – Enable the SSL connection to sanctions.io: The SAP system has to connect as SSL client to api.sanctions.io and therefore requires an active SSL service and has to trust the SSL server.

To enable this:

1. Check the SSL server status of the SAP system in transaction SMICM -> Goto -> Services:
There must be an active HTTPS service.

2. In transaction SM59, create an HTTP Connection to External Server (type G):
Name of the connection=SANCTIONS.IO (can be changed)
Target Host:Port=api.sanctions.io:8443
Logon Procedure=No Logon (authentication uses the API key that is sent via HTTPS)
SSL Status: Active
SSL Client Certificate: SSL Client (Anonymous)

3. In transaction STRUST, establish a trust relationship to the SSL server at https://api.sanctions.io:8443
Download the self-signed X.509 certificate from https://api.sanctions.io:8443
Import this certificate to the certificate list of the SSL Client (Anonymous).
We use a self-signed certificate with extended lifetime so that maintenance of the trust relationship in STRUST becomes minimal and you do not have to renew the certificate every few months.
If you prefer a CA-issued SSL server certificate, you can use port 443.

Important notes:
1. This report does not perform an AUTHORITY-CHECK when executed: make sure you apply appropriate security mechanisms before deploying this.

2. This template report comes with no warranty. It has been used in several environments without problems, but running this check against large sets of data can have an impact on the performance of your SAP system.

To use this report:
Enter a table name and field name that contains names, e.g. business partner names such as LFA1:NAME1, and select the sanction list against which you want to run the check.
You can also enter a name and check whether the name is on a list.
