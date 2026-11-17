allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

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

subprojects {
    if (project.name != "app") {
        val configureSdk: (Project) -> Unit = { p ->
            val android = p.extensions.findByName("android")
            if (android != null) {
                var applied = false
                for (method in android.javaClass.methods) {
                    if (method.name == "setCompileSdk" && method.parameterCount == 1) {
                        try {
                            method.invoke(android, 36)
                            applied = true
                            break
                        } catch (_: Throwable) {}
                    }
                }
                if (!applied) {
                    for (method in android.javaClass.methods) {
                        if (method.name == "compileSdkVersion" && method.parameterCount == 1) {
                            try {
                                if (method.parameterTypes[0] == Int::class.javaPrimitiveType) {
                                    method.invoke(android, 36)
                                    applied = true
                                    break
                                } else if (method.parameterTypes[0] == String::class.java) {
                                    method.invoke(android, "android-36")
                                    applied = true
                                    break
                                }
                            } catch (_: Throwable) {}
                        }
                    }
                }
            }
        }

        if (state.executed) {
            configureSdk(this)
        } else {
            afterEvaluate {
                configureSdk(this)
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
