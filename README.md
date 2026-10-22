# EKS Practice Project

This repository is being built in milestones. The first milestone is only the local React + Spring Boot application and its MySQL database. Terraform, Helm, and Jenkins folders are placeholders for later phases; no AWS resources or CI/CD pipelines are created yet.

## Current Application

- `frontend/` - React employee portal.
- `springboot-backend/` - existing Spring Boot API. It remains under this name for now because its local Java process is running; rename it to `backend/` after stopping that process.
- `database/init.sql` - creates the local application database.
- `terraform/`, `helm/`, and `jenkins/` - reserved for later milestones.

The frontend calls `http://localhost:8080/api/v1/employees`. The backend allows requests from `http://localhost:3000` and reads its database password from the `DB_PASSWORD` environment variable. Do not put the password in Git.

## Milestone 1: Local App

### Prerequisites

- MySQL Server running on port `3306`.
- A JDK compatible with this project and the Maven wrapper. The project targets Java 8.
- Node.js/npm. This project uses an older Create React App version; Node.js 16 is a suitable practice choice.

### Create the database

Connect to local MySQL as an administrator and run `database/init.sql`, or execute:

```sql
CREATE DATABASE IF NOT EXISTS employee_management_system;
```

### Start the backend

In PowerShell, set the password for this terminal session and start Spring Boot:

```powershell
$env:DB_PASSWORD = "<your-local-MySQL-password>"
cd springboot-backend
.\mvnw.cmd spring-boot:run
```

Leave that terminal running. Check the API from another PowerShell window:

```powershell
Invoke-RestMethod http://localhost:8080/api/v1/employees
```

An empty list (`[]`) is a successful response when there are no employees yet.

### Start the frontend

In another PowerShell window:

```powershell
cd frontend
npm install --legacy-peer-deps
npm start
```

Open `http://localhost:3000`, create an employee, and verify it appears in the list. Keep both the backend and frontend terminals open while testing.

## Next Milestones

1. Create or rename the GitHub repository to `eks-practice-project`, update the `origin` remote only after the new repository exists, then push this project.
2. Complete local app testing before adding Jenkins or AWS infrastructure.
3. Add Jenkins and application CI in the `jenkins/` folder.
4. Add EKS Terraform in `terraform/` only after AWS account security and budget alerts are configured.
5. Add application and supporting-service charts in `helm/` after the cluster is ready.

AWS account creation, MFA, billing alerts, repository creation, and pushing to GitHub require your account actions. Review AWS costs carefully before creating EKS resources.