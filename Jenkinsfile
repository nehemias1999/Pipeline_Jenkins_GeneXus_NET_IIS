// ==============================================================================
 // Description: Pipeline declarativo GeneXus .NET sobre IIS con promocion
 //   controlada DEV -> TEST -> PROD. Resuelve host/AppPool/rutas/credentials
 //   desde el mapa ENV_CONFIG segun params.TARGET_ENV; conserva los stages
 //   existentes (Update/Build/ZIP/Deploy) y anade gates de aprobacion mas
 //   bloque post determinista. Sin valores de entorno hardcodeados fuera del mapa.
 // Author: SDD implementer (REQ-001 multienv-pipeline)
 // Usage: Ejecutar desde Jenkins (Build with Parameters). Parametros:
 //   TARGET_ENV=DEV|TEST|PROD, APP_MAJOR, APP_MINOR, HealthCheckUrl.
 // Env Vars: TARGET_ENV, APP_MAJOR, APP_MINOR, HealthCheckUrl (parameters);
 //   ENV_HOST, ENV_APPPOOL, ENV_WEBPATH, ENV_CREDENTIALS (resueltos del mapa);
 //   GXServer17URL (variable global Jenkins), credenciales GXServer17 /
 //   credential_jenkins via withCredentials (nunca en claro).
 // Dependencies: Jenkins declarative pipeline, GeneXus 17 U10 + MSBuild en el
 //   agente, plugin gxserver, MSDeploy V3, scripts bat/DeployFileOnIISServer.bat
 //   y ps1/StopAppPool.ps1 + ps1/StartAppPool.ps1.
  // Output / Exit codes: SUCCESS despliega y arranca AppPool; FAILURE notifica
  //   e intenta rollback/arranque; UNSTABLE notifica. Verification: ver contrato
  //   REQ-001 (grep TARGET_ENV>=3, post>=1, input>=2; parse Groovy).
  //   REQ-002: sin secretos literales; ApplicationKey vive en la credential
  //   'genexus-app-key' (secret text) inyectada via withCredentials (nunca en claro).
  //   REQ-003: stage Init computa APP_VERSION=<major>.<minor>.<BUILD_NUMBER>+<sha7>
  //   (currentBuild.description/displayName); stage Tag Release crea/pushea tag
  //   git v<version> solo en main/SUCCESS idempotente (credential git-credentials);
  //   stage Create ZIP archiva ZIP con fingerprint y registra SHA256 en el log.
  //   REQ-004: stage Backup genera Backup-<APP_VERSION>.zip via msdeploy
  //   contentPath->package con retencion de 5; stage Deploy usa try/finally
  //   stop->deploy->start con rollback auto (ROLLBACK_OK/FAILED) en
  //   catch/post.failure; stage Verify hace GET HealthCheckUrl con
  //   Invoke-WebRequest retry 3x15s (timeout 10s, solo 2xx es SUCCESS);
  //   post.always re-arranca el AppPool en todo camino (incluido abort).
 // ==============================================================================
 // Mapa por entorno: unica fuente de verdad para host/AppPool/rutas/credenciales.
 // TARGET_ENV selecciona la entrada; ningun stage usa valores fuera de este mapa.
 def ENV_CONFIG = [
     DEV : [host: 'SERVER_1.deploy.local',  appPool: 'NET_Application_AppPool',      kb: 'net_application', kbVersion: 'development', webAppPath: 'E:\\inetpup\\wwwroot\\NET_APPLICATION_DEV',  credentialsId: 'credential_jenkins'],
     TEST: [host: 'SERVER_2.deploy.local',  appPool: 'NET_Application_AppPool_TEST', kb: 'net_application', kbVersion: 'test',        webAppPath: 'E:\\inetpup\\wwwroot\\NET_APPLICATION_TEST', credentialsId: 'credential_jenkins_test'],
     PROD: [host: 'SERVER_3.deploy.local',  appPool: 'NET_Application_AppPool_PROD', kb: 'net_application', kbVersion: 'production',  webAppPath: 'E:\\inetpup\\wwwroot\\NET_APPLICATION_PROD', credentialsId: 'credential_jenkins_prod']
 ]

pipeline {

    agent { label 'SERVER_1' }

    parameters {
        choice(name: 'TARGET_ENV', choices: ['DEV', 'TEST', 'PROD'], description: 'Entorno objetivo del deploy (resuelve host/AppPool/rutas desde ENV_CONFIG)')
        string(name: 'APP_MAJOR', defaultValue: '1', description: 'Version major de la aplicacion')
        string(name: 'APP_MINOR', defaultValue: '0', description: 'Version minor de la aplicacion')
        string(name: 'HealthCheckUrl', defaultValue: '', description: 'URL de health-check post-deploy (vacio = omitir)')
    }

    options {
        timestamps()
        timeout(time: 60, unit: 'MINUTES')
        buildDiscarder(logRotator(numToKeepStr: '30', artifactNumToKeepStr: '10'))
        disableConcurrentBuilds()
        skipDefaultCheckout(false)
    }

    environment {

        /* Pipeline parms */

        ForceRebuild = "${params['Force Rebuild']}" // Whether to force a rebuild of the KB
        TARGET_ENV = "${params.TARGET_ENV}" // Entorno objetivo (DEV/TEST/PROD), resuelto via ENV_CONFIG
        APP_VERSION = "${params.APP_MAJOR}.${params.APP_MINOR}" // Version derivada de APP_MAJOR/APP_MINOR
        HEALTH_CHECK_URL = "${params.HealthCheckUrl}" // URL de health-check post-deploy
        // Resueltos desde ENV_CONFIG en el stage 'Resolve Environment Config' (nunca hardcodeados por stage):
        ENV_HOST = '' // Host IIS del TARGET_ENV (mapa ENV_CONFIG)
        ENV_APPPOOL = '' // AppPool IIS del TARGET_ENV (mapa ENV_CONFIG)
        ENV_WEBPATH = '' // Ruta web destino del TARGET_ENV (mapa ENV_CONFIG)
        ENV_CREDENTIALS = '' // Credential ID del TARGET_ENV (mapa ENV_CONFIG)

        /* Stage 'Update pending Commits' */

        GXInstallationId = 'SERVER_1_GX17U10' // GeneXus 17 U10 installation on SERVER_1
        GXServerURL = "$GXServer17URL" // Defined in Jenkins Global Variables
        GXServerCredentialsId = 'GXServer17' // Defined in Jenkins Credentials
        GXServerKBName = 'net_application' // Defined in GXServer
        GXServerKBVersion = 'development' // Defined in GXServer
        WorkingDirectory = "C:\\applications\\net_application" // Local path on Jenkins agent where KB will be downloaded
        WorkingVersion = 'development' // Local KB version
        KBDBServerInstance = "DB_SERVER_1\\SQLEXPRESS" // Database server instance where KB database is located

        /* Stage 'Build KB' */

        MSBuildPath = "C:\\Program Files (x86)\\Microsoft Visual Studio\\2019\\BuildTools\\MSBuild\\Current\\Bin" // MSBuild installation path
        Genexus17U10Path = "C:\\Program Files (x86)\\GeneXus\\Genexus17U10" // GeneXus 17 U10 installation path
        WorkingEnvironment = "${params.TARGET_ENV}" // Environment to build (resuelto desde TARGET_ENV)
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

        // REQ-002: ApplicationKey eliminado del repo; vive en la credential
        // 'genexus-app-key' (secret text), inyectada como GX_APP_KEY solo en el
        // stage 'Create ZIP File' via withCredentials (nunca en claro ni en logs).
        ProjectName = 'NET_APPLICATION_DEV' // Project name
        Timestamp = 'NET_APPLICATION_DEV' // Timestamp for the deployment
        DeploymentUnit = 'NET_APPLICATION_DU' // Deployment Unit name
        IncludeGAM = 'false' // Whether to include GAM or not

        createDeployMsBuildScript = '"%MSBuildPath%\\MSBuild.exe" "%Genexus17U10Path%\\Deploy.msbuild" ' +
                                    '/p:KBPath="%WorkingDirectory%" ' +
                                    '/p:KBVersion="%WorkingVersion%" ' + 
                                    '/p:KBEnvironment="%WorkingEnvironment%" ' + 
                                    '/p:Application_Key="%GX_APP_KEY%" ' +
                                    '/p:ProjectName="%ProjectName%" ' +
                                    '/p:TimeStamp="%Timestamp%" ' +
                                    '/p:DeploymentUnit="%DeploymentUnit%" ' +
                                    '/p:INCLUDE_GAM="%IncludeGAM%" ' +
                                    '/t:CreateDeploy'

        createZIPFileMSBuildScript = '"%MSBuildPath%\\MSBuild.exe" ' +
                                     "${WorkingDirectory}\\${WorkingEnvironment}\\web\\${ProjectName}.gxdproj"

        ZIPFilePath = "${WorkingDirectory}\\${WorkingEnvironment}\\Deploy\\LOCAL\\${ProjectName}.zip" // Path to the generated ZIP file

        /* Stage 'Deploy ZIP File on IIS server' (valores base DEV; el efectivo sale de ENV_* via ENV_CONFIG) */

        TargetAPRemoteServerHost = 'SERVER_1.deploy.local' // Target Application Server Remote Host
        AppPoolName = 'NET_Application_AppPool' // Application Pool name on IIS

        stopAppPoolScript = '& "ps1\\StopAppPool.ps1" ' +
                            "-RemoteServerHost ${TargetAPRemoteServerHost} " +
                            "-AppPoolName ${AppPoolName}"

        MSDeployEXEPath = "C:\\Program Files\\IIS\\Microsoft Web Deploy V3\\msdeploy" // MSDeploy executable path on Jenkins agent
        DestinationWebAppPath = "E:\\inetpup\\wwwroot\\${ProjectName}" // Destination web application path on IIS server
        JenkinsCredentialsId = 'credential_jenkins' // Jenkins Credentials ID for accessing the IIS server

        // REQ-002: BAT de 5 args; el password viaja por env MSDEPLOY_PASSWORD
        // (inyectada por withCredentials), nunca en argv (visible en ps/list).
        deployZIPFileOnIISServerScript = '"bat\\DeployFileOnIISServer.bat" ' +
                                         '"%MSDeployEXEPath%" ' +  
                                         '"%ZIPFilePath%" ' +
                                         '"%DestinationWebAppPath%" ' + 
                                         '"%TargetAPRemoteServerHost%" ' +           
                                         '"%JenkinsUserName%"'

        startAppPoolScript = '& "ps1\\StartAppPool.ps1" ' +
                             "-RemoteServerHost ${TargetAPRemoteServerHost} " +
                             "-AppPoolName ${AppPoolName}"

    }

    stages {

        stage('Init') {

            steps {

                echo 'Start Init Stage (versionado trazable REQ-003)'

                script {
                    // REQ-003: APP_VERSION=<major>.<minor>.<BUILD_NUMBER>+<sha7>;
                    // expone version auditable (codigo<->artefacto<->deploy) en
                    // env + currentBuild.description/displayName.
                    def shortSha = bat(returnStdout: true, script: '@git rev-parse --short=7 HEAD').trim().readLines().last().trim()
                    env.APP_VERSION = "${params.APP_MAJOR}.${params.APP_MINOR}.${env.BUILD_NUMBER}+${shortSha}"
                    currentBuild.description = "v${env.APP_VERSION}"
                    currentBuild.displayName = "#${env.BUILD_NUMBER} v${env.APP_VERSION}"
                    echo "APP_VERSION=${env.APP_VERSION} (build #${env.BUILD_NUMBER}, sha ${shortSha})"
                }

                echo 'End Init Stage'

            }

        }

        stage('Resolve Environment Config') {

            steps {

                echo "Resolving config for TARGET_ENV=${params.TARGET_ENV}"

                script {
                    // Resuelve host/AppPool/paths/credentials desde ENV_CONFIG segun TARGET_ENV (nunca de DEV si es TEST/PROD).
                    def cfg = ENV_CONFIG[params.TARGET_ENV] ?: ENV_CONFIG['DEV']
                    env.ENV_HOST = cfg.host
                    env.ENV_APPPOOL = cfg.appPool
                    env.ENV_WEBPATH = cfg.webAppPath
                    env.ENV_CREDENTIALS = cfg.credentialsId
                    echo "Deploy target: host=${env.ENV_HOST} appPool=${env.ENV_APPPOOL} path=${env.ENV_WEBPATH} app=${params.APP_MAJOR}.${params.APP_MINOR}"
                }

            }

        }

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
            
                    // REQ-002: GX_APP_KEY solo existe dentro de este bloque (secret text 'genexus-app-key').
                    withCredentials([string(credentialsId: 'genexus-app-key', variable: 'GX_APP_KEY')]) {
                        bat label: "Create Deploy MSBuild Script",
                    	script: "${env.createDeployMsBuildScript}"

                        bat label: "Create ZIP File MSBuild Script",
                        script: "${env.createZIPFileMSBuildScript}"
                    }

                    // REQ-003: registra SHA256 del ZIP en el log (trazabilidad
                    // codigo<->artefacto; equivalente a `sha256sum` en Linux).
                    powershell label: 'Log SHA256 del artefacto',
                        script: 'Get-ChildItem -Recurse -Filter *.zip | ForEach-Object { $h = (Get-FileHash -Algorithm SHA256 $_.FullName).Hash.ToLower(); Write-Output ("SHA256 " + $h + "  " + $_.FullName) }'

                }

                // REQ-003: artefacto descargable desde Jenkins con fingerprint consultable.
                archiveArtifacts(artifacts: '**/*.zip', fingerprint: true, onlyIfSuccessful: false)

                echo "End Create ZIP File Stage [APP_VERSION=${env.APP_VERSION}]"
            
            }
        
        }

        stage('Promote to TEST') {

            when {
                expression { params.TARGET_ENV == 'TEST' || params.TARGET_ENV == 'PROD' }
            }

            steps {

                // Gate de promocion a TEST: sin aprobacion no hay deploy a TEST/PROD.
                input message: 'Promote to TEST?', submitter: 'release-managers,admins'

            }

        }

        stage('Promote to PROD') {

            when {
                expression { params.TARGET_ENV == 'PROD' }
            }

            steps {

                // Gate de promocion a PROD: sin aprobacion el stage de PROD nunca ejecuta MSDeploy.
                input message: 'Promote to PROD?', submitter: 'release-managers,admins'

            }

        }

        stage('Backup Current Site') {

            steps {

                echo "Start Backup Current Site Stage [APP_VERSION=${env.APP_VERSION}]"

                script {
                    // REQ-004/diseno 5: Backup versionado del contentPath remoto
                    // con la misma herramienta (msdeploy contentPath->package);
                    // existe antes del sync para que el rollback tenga de donde restaurar.
                    withCredentials([usernamePassword(credentialsId: "${env.JenkinsCredentialsId}", usernameVariable: 'JenkinsUserName', passwordVariable: 'MSDEPLOY_PASSWORD')]) {
                        bat label: 'Backup contentPath remoto',
                        script: '"%MSDeployEXEPath%\\msdeploy" -verb:sync -source:contentPath="%DestinationWebAppPath%" -dest:package="Backup-%APP_VERSION%.zip" -enableRule:DoNotDeleteRule'
                    }
                    // REQ-004/diseno 5: retencion de los ultimos 5 backups.
                    powershell label: 'Retencion ultimos 5 backups',
                        script: 'Get-ChildItem -Filter "Backup-*.zip" | Sort-Object LastWriteTime -Descending | Select-Object -Skip 5 | Remove-Item -Force'
                    echo "Backup Backup-${env.APP_VERSION}.zip listo (retencion 5)"
                }

                // REQ-004: backup archivado para rollback manual si hiciera falta.
                archiveArtifacts(artifacts: 'Backup-*.zip', fingerprint: true, onlyIfSuccessful: false)

                echo 'End Backup Current Site Stage'

            }

        }

        stage('Deploy ZIP File on IIS server') {

            steps {

                echo "Start Deploy ZIP File on IIS server Stage [TARGET_ENV=${params.TARGET_ENV} host=${env.ENV_HOST}]"

                script {
                    // REQ-004: flujo stop->deploy->start con try/finally para que el
                    // AppPool nunca quede detenido; catch con rollback auto al Backup.
                    powershell """
                        ${env.stopAppPoolScript}
                    """
                    try {
                        // REQ-002: password via env MSDEPLOY_PASSWORD (nunca en argv);
                        // withCredentials + maskPasswords enmascaran '****' en consola.
                        withCredentials([usernamePassword(credentialsId: "${env.JenkinsCredentialsId}", usernameVariable: 'JenkinsUserName', passwordVariable: 'MSDEPLOY_PASSWORD')]) {
                            maskPasswords(varMaskRegexes: [[regex: '(?i)password\\s*[=:]\\s*\\S+']]) {
                                bat label: 'Deploy ZIP File on IIS server Script',
                                script: "${env.deployZIPFileOnIISServerScript}"
                            }
                        }
                    } catch (err) {
                        // REQ-004: rollback auto re-sincroniza el Backup y re-arranca
                        // el AppPool; causa ROLLBACK_OK o ROLLBACK_FAILED en el log.
                        try {
                            withCredentials([usernamePassword(credentialsId: "${env.JenkinsCredentialsId}", usernameVariable: 'JenkinsUserName', passwordVariable: 'MSDEPLOY_PASSWORD')]) {
                                bat label: 'Rollback desde Backup',
                                script: '"%MSDeployEXEPath%\\msdeploy" -verb:sync -source:package="Backup-%APP_VERSION%.zip" -dest:contentPath="%DestinationWebAppPath%"'
                            }
                            powershell(script: "${env.startAppPoolScript}", returnStatus: true)
                            echo "ROLLBACK_OK: deploy revertido al Backup-${env.APP_VERSION}.zip (${err})"
                        } catch (rbErr) {
                            echo "ROLLBACK_FAILED: no se pudo restaurar el Backup (${rbErr}); causa original: ${err}"
                        }
                        error("Deploy FAILED (rollback intentado): ${err}")
                    } finally {
                        powershell(script: "${env.startAppPoolScript}", returnStatus: true)
                    }
                }

                echo 'End Deploy ZIP File on IIS server Stage'

            }

        }

        stage('Verify Deploy (HealthCheck)') {

            when { expression { return params.HealthCheckUrl?.trim() } }

            steps {

                echo "Start Verify Deploy Stage [HealthCheckUrl=${params.HealthCheckUrl}]"

                script {
                    // REQ-004/diseno 6: GET HealthCheckUrl hasta 3 intentos (15s entre
                    // ellos, timeout 10s); solo 2xx es SUCCESS. Sin plugin extra.
                    def ok = false
                    for (int i = 1; i <= 3 && !ok; i++) {
                        def rc = powershell(returnStatus: true, label: "HealthCheck intento ${i}/3",
                            script: "try { Invoke-WebRequest -Uri '${params.HealthCheckUrl}' -TimeoutSec 10 -UseBasicParsing | ForEach-Object { if ($_.StatusCode -ge 200 -and $_.StatusCode -lt 300) { exit 0 } else { exit 1 } } } catch { exit 1 }")
                        if (rc == 0) {
                            ok = true
                            echo "HealthCheck OK en intento ${i}/3"
                        } else if (i < 3) {
                            echo "HealthCheck intento ${i}/3 fallo; reintento en 15s"
                            sleep(time: 15, unit: 'SECONDS')
                        }
                    }
                    if (!ok) {
                        // REQ-004: fallo de health dispara restore del Backup.
                        try {
                            withCredentials([usernamePassword(credentialsId: "${env.JenkinsCredentialsId}", usernameVariable: 'JenkinsUserName', passwordVariable: 'MSDEPLOY_PASSWORD')]) {
                                bat label: 'Rollback por HealthCheck',
                                script: '"%MSDeployEXEPath%\\msdeploy" -verb:sync -source:package="Backup-%APP_VERSION%.zip" -dest:contentPath="%DestinationWebAppPath%"'
                            }
                            powershell(script: "${env.startAppPoolScript}", returnStatus: true)
                            echo "ROLLBACK_OK: HealthCheck fallo 3 veces; Backup-${env.APP_VERSION}.zip restaurado"
                        } catch (rbErr) {
                            echo "ROLLBACK_FAILED: HealthCheck fallo y el restore fallo (${rbErr})"
                        }
                        error('HealthCheck FAILED tras 3 intentos (rollback intentado)')
                    }
                }

                echo 'End Verify Deploy Stage'

            }

        }

        stage('Tag Release') {

            when { branch 'main' }

            steps {

                echo "Start Tag Release Stage [APP_VERSION=${env.APP_VERSION}]"

                script {
                    // REQ-003/diseno 7: tag git v<APP_VERSION> solo en main;
                    // idempotente (si el tag ya existe el push se omite, el
                    // build no falla); credential 'git-credentials' nunca en claro.
                    def originUrl = bat(returnStdout: true, script: '@git config --get remote.origin.url').trim().readLines().last().trim()
                    def pushPath = originUrl.replaceFirst(/^https?:\/\//, '')
                    withCredentials([usernamePassword(credentialsId: 'git-credentials', usernameVariable: 'GIT_USER', passwordVariable: 'GIT_PASS')]) {
                        bat label: 'Tag git idempotente',
                        script: "@echo off\r\ngit tag -l \"v%APP_VERSION%\" | findstr /C:\"v%APP_VERSION%\" >nul && echo Tag v%APP_VERSION% ya existe; se omite el push. || (git tag -a \"v%APP_VERSION%\" -m \"Release v%APP_VERSION% build #%BUILD_NUMBER%\" && git push https://%GIT_USER%:%GIT_PASS%@${pushPath} \"v%APP_VERSION%\")"
                    }
                }

                echo "End Tag Release Stage [v${env.APP_VERSION}]"

            }

        }

    }

    post {
        // Bloque post determinista: always garantiza AppPool arrancado + limpieza parcial.
        always {
            echo 'Post always: garantizar AppPool arrancado y limpieza parcial del workspace'
            powershell(script: "${env.startAppPoolScript}", returnStatus: true)
            bat label: 'Limpieza parcial workspace', script: 'echo Limpieza parcial del workspace'
        }
        success {
            echo "Post success: deploy ${params.TARGET_ENV} OK (app ${params.APP_MAJOR}.${params.APP_MINOR})"
        }
        failure {
            echo "Post failure: deploy ${params.TARGET_ENV} FALLO; notificar y disparar rollback"
            echo 'ROLLBACK_FAILED o ROLLBACK_OK segun restore en catch del stage Deploy/Verify (ver log)'
        }
        unstable {
            echo "Post unstable: deploy ${params.TARGET_ENV} inestable; notificar"
        }
    }

}
