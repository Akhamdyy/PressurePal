allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}

subprojects {
    project.evaluationDependsOn(":app")
}

// --- FIX FOR OUTDATED PLUGINS (like telephony) ---
subprojects {
    val subproject = this
    
    // 1. Define the logic to fix the namespace
    fun fixNamespace() {
        val android = subproject.extensions.findByName("android")
        if (android != null) {
            try {
                // Reflection to access 'namespace' property safely
                val getNamespace = android.javaClass.getMethod("getNamespace")
                val currentNamespace = getNamespace.invoke(android)

                if (currentNamespace == null) {
                    val setNamespace = android.javaClass.getMethod("setNamespace", String::class.java)
                    val fallbackNamespace = if (subproject.group.toString().isEmpty()) {
                        "com.example.${subproject.name}"
                    } else {
                        subproject.group.toString()
                    }
                    setNamespace.invoke(android, fallbackNamespace)
                    println("✅ Auto-patched namespace for ${subproject.name} to $fallbackNamespace")
                }
            } catch (e: Exception) {
                // Ignore if AGP version is too old or too new to support this
            }
        }
    }

    // 2. Apply it safely (Check if already evaluated)
    if (subproject.state.executed) {
        fixNamespace()
    } else {
        subproject.afterEvaluate {
            fixNamespace()
        }
    }
}
// -------------------------------------------------

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}