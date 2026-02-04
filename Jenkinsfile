pipeline {

    agent { label 'SERVER_1' }

    environment {

        /* Pipeline parms */

        ForceRebuild = "${params['Realizar Rebuild']}" // Whether to force a rebuild of the KB

        /* Stage 'Update pending Commits' */

        GXInstallationId = 'SERVER_1_GX17U10' // GeneXus 17 U10 installation on SERVER_1
        GXServerURL = "$GXServer17URL" // Defined in Jenkins Global Variables
        GXServerCredentialsId = 'GXServer17' // Defined in Jenkins Credentials
        GXServerKBName = 'net_application' // Defined in GXServer
        GXServerKBVersion = 'development' // Defined in GXServer
        WorkingDirectory = "C:\\applications\\net_application" // Local path on Jenkins agent where KB will be downloaded
        WorkingVersion = 'development' // Local KB version
        KBDBServerInstance = "AR-DEV-JNODE-3\\SQLEXPRESS" // Database server instance where KB database is located

        /* Stage 'Build KB' */

        MSBuildPath = "C:\\Program Files (x86)\\Microsoft Visual Studio\\2019\\BuildTools\\MSBuild\\Current\\Bin" // MSBuild installation path
        Genexus17U10Path = "C:\\Program Files (x86)\\GeneXus\\Genexus17U10" // GeneXus 17 U10 installation path
        WorkingEnvironment = 'DEV' // Environment to build
        CompileMains = 'true' // Whether to compile mains or not

        buildMSBuildScript = '"%MSBuildPath%\\MSBuild.exe" "%Genexus17U10Path%\\TeamDev.msbuild" ' +
                             '/p:GX_PROGRAM_DIR="%Genexus17U10Path%" ' +
                             '/p:WorkingDirectory="%WorkingDirectory%" ' +
                             '/p:DbaseServerUsername="%GXServerUserName%" ' +
                             '/p:DbaseServerPassword="%GXServerPassword%" ' +
                             '/p:WorkingVersion="%WorkingVersion%" ' +
                             '/p:WorkingEnvironment="%WorkingEnvironment%" ' +
                             '/p:ForceRebuild="%ForceRebuild%" ' + 
                             '/p:CompileMains="%CompileMains%" ' +
                             '/t:Build'

        /* Stage 'Create ZIP File' */

        ApplicationKey = 'DE6F1DCAD523A253749128F1AA89BED04B65785142228A3927E37C37D8325AA9' // Application Key of the KB
        ProjectName = 'NET_APPLICATION_DEV' // Project name
        Timestamp = 'NET_APPLICATION_DEV' // Timestamp for the deployment
        DeploymentUnit = 'NET_APPLICATION_DU' // Deployment Unit name
        IncludeGAM = 'false' // Whether to include GAM or not

        createDeployMsBuildScript = '"%MSBuildPath%\\MSBuild.exe" "%Genexus17U10Path%\\Deploy.msbuild" ' +
                                    '/p:KBPath="%WorkingDirectory%" ' +
                                    '/p:KBVersion="%WorkingVersion%" ' +
                                    '/p:KBEnvironment="%WorkingEnvironment%" ' + 
                                    '/p:Application_Key="%ApplicationKey%" ' + 
                                    '/p:ProjectName="%ProjectName%" ' +
                                    '/p:TimeStamp="%Timestamp%" ' +
                                    '/p:DeploymentUnit="%DeploymentUnit%" ' +
                                    '/p:INCLUDE_GAM="%IncludeGAM%" ' +
                                    '/t:CreateDeploy'

        createZIPFileMSBuildScript = '"%MSBuildPath%\\MSBuild.exe" ' +
                                     "${WorkingDirectory}\\${WorkingEnvironment}\\web\\${ProjectName}.gxdproj"

        ZIPFilePath = "${WorkingDirectory}\\${WorkingEnvironment}\\Deploy\\LOCAL\\${ProjectName}.zip" // Path to the generated ZIP file

        /* Stage 'Deploy ZIP File on IIS server' */

        TargetAPRemoteServerHost = 'SERVER_1.deploy.local' // Target Application Server Remote Host
        AppPoolName = 'NET_Application_AppPool' // Application Pool name on IIS

        stopAppPoolScript = '& "ps1\\StopAppPool.ps1" ' +
                            "-RemoteServerHost ${TargetAPRemoteServerHost} " +
                            "-AppPoolName ${AppPoolName}"

        MSDeployEXEPath = "C:\\Program Files\\IIS\\Microsoft Web Deploy V3\\msdeploy" // MSDeploy executable path on Jenkins agent
        DestinationWebAppPath = "E:\\inetpup\\wwwroot\\${ProjectName}" // Destination web application path on IIS server
        JenkinsCredentialsId = 'credential_jenkins' // Jenkins Credentials ID for accessing the IIS server

        deployZIPFileOnIISServerScript = '"bat\\DeployFileOnIISServer.bat" ' +
                                         '"%MSDeployEXEPath%" ' +  
                                         '"%ZIPFilePath%" ' +
                                         '"%DestinationWebAppPath%" ' + 
                                         '"%TargetAPRemoteServerHost%" ' +           
                                         '"%JenkinsUserName%" ' +
                                         '"%JenkinsPassword%"'

        startAppPoolScript = '& "ps1\\StartAppPool.ps1" ' +
                             "-RemoteServerHost ${TargetAPRemoteServerHost} " +
                             "-AppPoolName ${AppPoolName}"

    }

    stages {

        stage('Update pending Commits') {

            steps {

                echo 'Start Update pending Commits Stage'

                gxserver changelog: true, poll: true,
                         gxInstallationId: "${env.GXInstallationId}",
                         serverURL: "${env.GXServerURL}",
                         credentialsId: "${env.GXServerCredentialsId}",
                         kbName: "${env.GXServerKBName}",
                         kbVersion: "${env.GXServerKBVersion}", 
                         localKbPath: "${env.WorkingDirectory}",
                         localKbVersion: "${env.WorkingVersion}",
                         kbDbServerInstance: "${env.KBDBServerInstance}",
                         kbDbInSameFolder: false

                echo 'End Update pending Commits Stage'

            }

        }

        stage('Build KB') {

            steps {

                echo 'Start Build KB Stage'
                
                script {

                    withCredentials([usernamePassword(credentialsId: "${env.GXServerCredentialsId}", usernameVariable: 'GXServerUserName', passwordVariable: 'GXServerPassword')]) {

                        bat label: 'Build KB Script',
                        script: "${env.buildMSBuildScript}"

                    }

                }

                echo 'End Build KB Stage'

            }

        }

        stage ('Create ZIP File') {

            steps {

                echo 'Start Create ZIP File Stage'
            
                script {
            
                    bat label: "Create Deploy MSBuild Script",
                	script: "${env.createDeployMsBuildScript}"

                    bat label: "Create ZIP File MSBuild Script",
                    script: "${env.createZIPFileMSBuildScript}"

                }

                echo 'End Create ZIP File Stage'
            
            }
        
        }

        stage('Deploy ZIP File on IIS server') {

            steps {

                echo 'Start Deploy ZIP File on IIS server Stage'

                powershell """
                    ${env.stopAppPoolScript}
                """

                script {

                    withCredentials([usernamePassword(credentialsId: "${env.JenkinsCredentialsId}", usernameVariable: 'JenkinsUserName', passwordVariable: 'JenkinsPassword')]) {

                        bat label: 'Deploy ZIP File on IIS server Script', 
                        script: "${env.deployZIPFileOnIISServerScript}"

                    }

                }

                powershell """
                    ${env.startAppPoolScript}
                """

                echo 'End Deploy ZIP File on IIS server Stage'

            }

        }

    }

}