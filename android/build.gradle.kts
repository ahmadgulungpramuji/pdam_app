plugins {
    // Versi Android tetap 8.7.0 (Sesuai error pertama)
    id("com.android.application") version "8.7.0" apply false
    
    // Versi Kotlin tetap 1.8.22 (Sesuai error kedua)
    id("org.jetbrains.kotlin.android") version "1.8.22" apply false
    
    // REVISI: Mengubah versi Google Services ke 4.3.15 (Sesuai error Anda saat ini)
    id("com.google.gms.google-services") version "4.3.15" apply false
}

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

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}