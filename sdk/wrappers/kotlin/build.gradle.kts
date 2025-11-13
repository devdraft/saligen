plugins {
    kotlin("jvm") version "1.9.20"
    `maven-publish`
}

group = "com.devdraft"
version = "0.1.0"

repositories {
    mavenCentral()
}

dependencies {
    // Kotlin standard library
    implementation(kotlin("stdlib"))
    
    // Coroutines
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-core:1.7.3")
    
    // OkHttp for HTTP client
    implementation("com.squareup.okhttp3:okhttp:4.12.0")
    
    // Gson for JSON serialization
    implementation("com.google.code.gson:gson:2.10.1")
    
    // Test dependencies
    testImplementation(kotlin("test"))
    testImplementation("org.jetbrains.kotlinx:kotlinx-coroutines-test:1.7.3")
}

tasks.test {
    useJUnitPlatform()
}

kotlin {
    jvmToolchain(11)
}

java {
    sourceCompatibility = JavaVersion.VERSION_11
    targetCompatibility = JavaVersion.VERSION_11
    withSourcesJar()
    withJavadocJar()
}

publishing {
    publications {
        create<MavenPublication>("maven") {
            from(components["java"])
            
            pom {
                name.set("DevDraft Kotlin SDK")
                description.set("Production-ready Kotlin SDK for DevDraft API")
                url.set("https://github.com/devdraft/devdraft-kotlin")
                
                licenses {
                    license {
                        name.set("MIT License")
                        url.set("https://opensource.org/licenses/MIT")
                    }
                }
                
                developers {
                    developer {
                        name.set("devdraft")
                        email.set("engineering@devdraft.ai")
                    }
                }
                
                scm {
                    connection.set("scm:git:git://github.com/devdraft/devdraft-kotlin.git")
                    developerConnection.set("scm:git:ssh://github.com:devdraft/devdraft-kotlin.git")
                    url.set("https://github.com/devdraft/devdraft-kotlin")
                }
            }
        }
    }
}

