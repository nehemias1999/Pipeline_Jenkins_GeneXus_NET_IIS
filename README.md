# Jenkins Pipeline – GeneXus .NET Application Deployment to IIS

## Overview

This project implements a **CI/CD pipeline using Jenkins** to deploy a **GeneXus-generated .NET application** to a **remote IIS server**.

The pipeline automates the deployment of a packaged GeneXus application (`.zip`) to IIS using **MSDeploy**, and controls the **IIS Application Pool lifecycle** (stop/start) through remote PowerShell execution.

The objective of this pipeline is to provide a **reliable, repeatable, and automated deployment process** for GeneXus .NET applications in Windows environments.

---

## High-Level Workflow

1. Jenkins executes the pipeline defined in the `Jenkinsfile`.
2. The target IIS Application Pool is stopped on the remote server.
3. The application package is deployed to IIS using MSDeploy.
4. The IIS Application Pool is started again.
5. The pipeline reports success or failure.

---

## Technologies Used

- Jenkins – CI/CD automation and orchestration
- GeneXus – Low-code platform generating the .NET application
- .NET Framework / .NET – Application runtime
- Microsoft IIS – Web server hosting the application
- MSDeploy (Web Deploy) – Deployment tool for IIS
- PowerShell – Remote server management and App Pool control
- Batch scripting (.bat) – Deployment command execution
- WinRM / PowerShell Remoting – Remote execution on IIS server

---

## Project Structure

```
Pipeline_Jenkins_GeneXus_NET_IIS/
├── Jenkinsfile
├── bat/
│   └── DeployFileOnIISServer.bat
├── ps1/
│   ├── StartAppPool.ps1
│   └── StopAppPool.ps1
└── README.md
```

---

## Pipeline Steps

### 1. Stop IIS Application Pool
Stops the IIS Application Pool on the remote server before deployment to prevent file locks.

### 2. Deploy Application Package to IIS
Deploys the GeneXus-generated ZIP package using MSDeploy.

### 3. Start IIS Application Pool
Starts the IIS Application Pool after deployment.

---

## Security Considerations

- Manage credentials using Jenkins Credentials
- Secure PowerShell Remoting access
- Restrict MSDeploy permissions

---

## Conclusion

This pipeline provides a robust Jenkins-based deployment solution for GeneXus .NET applications on IIS.
