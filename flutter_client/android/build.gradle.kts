allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

extra["compileSdkVersion"] = 36
extra["targetSdkVersion"] = 36
extra["minSdkVersion"] = 21

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}

subprojects {
    val configureProject = {
        if (project.hasProperty("android")) {
            val android = project.extensions.findByName("android")
            if (android != null) {
                try {
                    // Try setting modern compileSdk property first (AGP 7.0+)
                    val method = android.javaClass.getMethod("setCompileSdk", java.lang.Integer::class.java)
                    method.invoke(android, 36)
                    println("DEBUG: Successfully set compileSdk = 36 on ${project.name} after evaluation")
                } catch (e: Exception) {
                    try {
                        // Fallback to legacy compileSdkVersion method
                        val method = android.javaClass.getMethod("compileSdkVersion", Int::class.javaPrimitiveType)
                        method.invoke(android, 36)
                        println("DEBUG: Successfully set compileSdkVersion(36) on ${project.name} after evaluation")
                    } catch (ex: Exception) {
                        println("DEBUG: Failed to override SDK on ${project.name}: ${ex.message}")
                    }
                }
            }
        }
    }

    if (project.state.executed) {
        configureProject()
    } else {
        project.afterEvaluate {
            configureProject()
        }
    }
}
