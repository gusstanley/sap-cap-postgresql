# SAP Cap Application using PostgreSQL 

This project implements the cap framework on BTP with its pre-requisites to use PostgreSQL.
Repository: https://github.com/guhstanley/sap-cap-postgresql

#### Authors: 
- Gustavo Stanley Silva
- Mateus Oliveira


## Requirements

- CF CLI: [https://github.com/cloudfoundry/cli/wiki/V7-CLI-Installation-Guide](https://github.com/cloudfoundry/cli/wiki/V7-CLI-Installation-Guide)
- CL MTA Plugin
```bash
cf install-plugin multiapps
```
- CF Environment on BTP
- Business Application Studio
- PostgreSQL Instance on BTP
- ServiceKey created for the postgresql instance

## Project configurations for PostgreSQL

Install the PostgreSQL dependency:

```bash
npm add @cap-js/postgres
```

Activate PostgreSQL:

```bash
cds add postgres
```

Change mta.yaml:

- Make sure that the resource name for the postgresql database matches with the instance name already created on BTP. If it is created as “postgres” on BTP it needs to be set as “postgres” in the resource name.
- Check if the service-plan matches what you’ve selected on BTP(eg: trial)
- Set the path parameter on the postgres resource so we can tell the deployer the instance properties.(eg: ./pg-options.json)

```yaml
_schema-version: '3.1'
ID: sap-cap-postgresql
version: 1.0.0
description: "A simple CAP project."
parameters:
  enable-parallel-deployments: true
build-parameters:
  before-all:
    - builder: custom
      commands:
        - npx cds build --production
modules:
  - name: sap-cap-postgresql-srv
    type: nodejs
    path: gen/srv
    parameters:
      buildpack: nodejs_buildpack
    build-parameters:
      builder: npm
    provides:
      - name: srv-api # required by consumers of CAP services (e.g. approuter)
        properties:
          srv-url: ${default-url}
    requires:
      - name: postgres

  - name: sap-cap-postgresql-postgres-deployer
    type: nodejs
    path: gen/pg
    parameters:
      buildpack: nodejs_buildpack
      no-route: true
      no-start: true
      tasks:
        - name: deploy-to-postgresql
          command: npm start
    requires:
      - name: postgres

resources:
  - name: postgres
    type: org.cloudfoundry.managed-service
    parameters:
      service: postgresql-db
      service-plan: trial
      path: ./pg-options.json
```

Create the pg-options.json on the root of the project. This file will hold instance attributes like engine version, locale, region.

```json
{
    "engine_version": "14"
}
```

Create the pg-package.json file on the root of the project. This will be used on the building phase for deploying our database to the PostgreSQL instance.

```json
{
    "engines": {
        "node": "^18"
    },
    "dependencies": {
        "@sap/cds": "*",
        "@cap-js/postgres": "^1.1.0"
    },
    "scripts": {
        "start": "cds-deploy"
    }
}
```

Change the mta.yaml to execute different commands on building. This process is used because we need the pg-package.json inside the gen/pb folder when building the project.

```bash
#REPLACE THIS BLOCK
build-parameters:
  before-all:
    - builder: custom
      commands:
        - npx cds build --production

#WITH THIS BLOCK FOR LINUX
build-parameters:
  before-all:
    - builder: custom
      commands:
        - npm install
        - npx -p @sap/cds-dk cds build --production
        - cp pg-package.json gen/pg/package.json
        - cp package-lock.json gen/pg/package-lock.json

#WITH THIS BLOCK FOR WINDOWS
#If the mkdir fails, comment the line
build-parameters:
  before-all:
    - builder: custom
      commands:
        - npm install
        - npx -p @sap/cds-dk cds build --production
        - cmd.exe /c mkdir gen\\pg\\db
        - cds compile '*' > gen/pg/db/csn.json
        - cmd.exe /c copy pg-package.json gen\\pg\\package.json
        - cmd.exe /c copy package-lock.json gen\\pg\\package-lock.json
```

Change the package.json to include the build and deploy script

```json
"scripts": {
    "start": "cds-serve",
    "build": "rimraf resources mta_archives && mbt build --mtar archive",
    "deploy": "cf deploy mta_archives/archive.mtar --retries 1"
  }
```

Add the rimraf package as devDependencies

```bash
npm install rimraf --save-dev
```

## PostgreSQL Adminer Tool:

Let’s deploy also the adminer tools so we can check if the database is running correcly. To do that we will need to add the following code to the module section of our mta.yaml

```yaml
# ------------------------------------------------------------
# name: postgres-adminer
# ------------------------------------------------------------
  - name: postgres-adminer
    type: application
    build-parameters:
      no-source: true
    parameters:
      # Only needed to track down issues in the PostgreSQL Database deployment
      no-route: false
      no-start: false 
      disk-quota: 1GB
      memory: 1024MB
      docker:
        image: dockette/adminer:pgsql
      instances: 1
    requires:
    - name: postgres
```

## Deploying the Project:

Follow the below script to deploy the project

```bash
npm install
npm run build
npm run deploy
```

## Developing Locally using Docker:

Create a the pg.yml file on the root of the project to be used by docker-compose to start the local PostgreSQL database:

```yaml
services:
  db:
    image: postgres:latest
    environment: { POSTGRES_PASSWORD: postgres }
    ports: [ '5432:5432' ]
    restart: always
```

Create a .env file on the root so the database can be connected:

```
cds.requires.db.kind = postgres
cds.requires.db.credentials.host = localhost
cds.requires.db.credentials.port = 5432
cds.requires.db.credentials.user = postgres
cds.requires.db.credentials.password = postgres
cds.requires.db.credentials.database = postgres
```

Change package.json to use mocked authentication as we are running it locally:

```json
"cds": {
  "requires": {
    "auth": "mocked"
  }
}
```

Add to package.json the following script:

```
"build:db": "docker-compose -f pg.yml up -d && cds deploy"
```

Execute the program:

```bash
npm install
npm run build:db
cds watch
```

## Deploying to BTP environment from local machine:

- Make sure you are logged into Cloud Foundry using the CF CLI.
- Check if you have the installed MBT package on your machine. This will be used to build the artifact.
    
    If not:
    
    ```bash
    npm install -g mbt
    ```
    
- Execute the following commands:
    
    ```bash
    npm install
    npm run build
    npm run deploy
    ```