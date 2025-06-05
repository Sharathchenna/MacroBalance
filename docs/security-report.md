# Security Audit Report

## Executive Summary
This security audit of the MacroBalance mobile application has identified several security vulnerabilities ranging from critical to low severity. The application is a Flutter-based mobile app that uses Supabase for authentication and data storage, Firebase for notifications, and integrates with various third-party services including RevenueCat, Apple Health, and Google Generative AI.

The most significant findings include hardcoded API keys, improper handling of sensitive user data, lack of input validation, and potential privacy concerns with health data. While the application uses established authentication providers, certain implementation practices could lead to security risks.

## Critical Vulnerabilities

### Hardcoded API Credentials
- **Location**: `/lib/main.dart` (lines ~137-139 and ~274-276)
- **Description**: Supabase anon key is hardcoded directly in the application code. This key provides access to your Supabase project and should not be embedded in the client application.
- **Impact**: Potential for unauthorized access to your Supabase project, database exfiltration, and backend compromise.
- **Remediation Checklist**:
  - [ ] Move sensitive API keys to secure environment variables or a secure key management system
  - [ ] Configure proper API key rotation mechanisms
  - [ ] Ensure API keys have the minimum necessary permissions
  - [ ] Consider implementing a backend proxy to handle sensitive operations requiring keys
- **References**: [OWASP Mobile Top 10 - M9: Improper Platform Usage](https://owasp.org/www-project-mobile-top-10/2016-risks/m9-improper-platform-usage)

### Exposed Firebase Configuration
- **Location**: `/lib/firebase_options.dart` (lines 42-57)
- **Description**: Firebase API keys and configuration are hardcoded in the application. While these keys are typically meant for client-side use, they should not be exposed in the source code.
- **Impact**: Could lead to unauthorized access to Firebase services if combined with other security issues.
- **Remediation Checklist**:
  - [ ] Use environment-specific configurations for different environments (dev, staging, prod)
  - [ ] Ensure Firebase security rules are properly configured
  - [ ] Restrict API key usage by setting up Application Restrictions in Google Cloud Console
- **References**: [Firebase Security Documentation](https://firebase.google.com/docs/projects/api-keys)

## High Vulnerabilities

### Insufficient Input Validation
- **Location**: Multiple files; notably absent in `/lib/screens/searchPage.dart` and data handling components
- **Description**: The application lacks consistent input sanitization and validation across several user input fields. This is particularly concerning in areas where user input may be used in queries or stored in the database.
- **Impact**: Potential for injection attacks, data corruption, or manipulation of application logic.
- **Remediation Checklist**:
  - [ ] Implement comprehensive input validation for all user inputs
  - [ ] Use parameterized queries when accessing databases
  - [ ] Sanitize data before storing or displaying it
  - [ ] Add client-side and server-side validation
- **References**: [OWASP Input Validation Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Input_Validation_Cheat_Sheet.html)

### Insecure Data Storage
- **Location**: `/lib/services/storage_service.dart` (throughout file)
- **Description**: Sensitive user data, including health and nutrition information, is stored in local storage (Hive) without proper encryption. Migration from SharedPreferences to Hive improves security somewhat, but does not provide sufficient protection for sensitive data.
- **Impact**: If a device is compromised or an attacker gains physical access, sensitive user data could be exposed.
- **Remediation Checklist**:
  - [ ] Encrypt sensitive data before storing in local storage
  - [ ] Use platform-specific secure storage for sensitive information (e.g., KeyStore/Keychain)
  - [ ] Implement proper key management for encryption keys
  - [ ] Consider what data actually needs to be cached locally
- **References**: [OWASP Mobile Top 10 - M2: Insecure Data Storage](https://owasp.org/www-project-mobile-top-10/2016-risks/m2-insecure-data-storage)

### Missing JWT Validation
- **Location**: `/lib/services/auth_service.dart` and related components 
- **Description**: The application does not appear to properly validate JWT tokens received from authentication processes. While using Supabase handles some aspects of token management, additional validation should be performed.
- **Impact**: Potential for token replay attacks or session hijacking.
- **Remediation Checklist**:
  - [ ] Verify token signatures before accepting them
  - [ ] Check token expiration and not-before claims
  - [ ] Validate the issuer and audience claims
  - [ ] Implement proper token refresh mechanisms
- **References**: [JWT Best Practices](https://auth0.com/docs/secure/tokens/json-web-tokens/validate-json-web-tokens)

## Medium Vulnerabilities

### Insufficient Error Handling
- **Location**: Multiple files; examples in `/lib/services/auth_service.dart` and `/lib/services/supabase_service.dart`
- **Description**: Error handling throughout the application often logs errors to the console but may not properly handle failures or inform users. In some cases, errors are caught but not appropriately handled.
- **Impact**: Poor error handling could lead to unexpected application behavior, information leakage, or a degraded security posture.
- **Remediation Checklist**:
  - [ ] Implement comprehensive error handling throughout the application
  - [ ] Avoid exposing sensitive information in error messages
  - [ ] Log errors securely for debugging purposes
  - [ ] Provide appropriate user feedback without technical details
- **References**: [OWASP Error Handling Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Error_Handling_Cheat_Sheet.html)

### Health Data Privacy Concerns
- **Location**: Health-related data handling in `/lib/Health/` directory, `/lib/screens/setting_screens/health_integration_screen.dart`
- **Description**: The application appears to collect and process sensitive health data but lacks comprehensive privacy controls and secure handling of this information.
- **Impact**: Potential privacy violations and regulatory non-compliance (e.g., with HIPAA, GDPR, or similar regulations).
- **Remediation Checklist**:
  - [ ] Implement proper consent mechanisms for health data collection
  - [ ] Store health data with appropriate encryption
  - [ ] Provide clear privacy notices about how health data is used
  - [ ] Implement data minimization principles
  - [ ] Consider regulatory requirements for health data in all target markets
- **References**: [HIPAA Security Rule](https://www.hhs.gov/hipaa/for-professionals/security/index.html), [GDPR Health Data Guidelines](https://gdpr-info.eu/art-9-gdpr/)

### Insecure Network Requests
- **Location**: HTTP requests in various services, particularly in `/lib/services/api_service.dart`
- **Description**: Some network requests may not properly validate server certificates or may not enforce HTTPS. Additionally, there is limited protection against man-in-the-middle attacks.
- **Impact**: Potential interception of sensitive data in transit.
- **Remediation Checklist**:
  - [ ] Enforce HTTPS for all network communications
  - [ ] Implement certificate pinning for critical API endpoints
  - [ ] Validate server certificates properly
  - [ ] Implement network security configurations to prevent cleartext traffic
- **References**: [OWASP Transport Layer Protection Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Transport_Layer_Protection_Cheat_Sheet.html)

## Low Vulnerabilities

### Outdated Dependencies
- **Location**: `/pubspec.yaml` and `/pubspec.lock`
- **Description**: Some dependencies may be outdated and contain known vulnerabilities.
- **Impact**: Known vulnerabilities in dependencies could be exploited.
- **Remediation Checklist**:
  - [ ] Implement a dependency management strategy that includes regular updates
  - [ ] Use tools like `npm audit` or similar to scan for vulnerable dependencies
  - [ ] Subscribe to security advisories for critical dependencies
  - [ ] Test application thoroughly after dependency updates
- **References**: [OWASP Dependency Check](https://owasp.org/www-project-dependency-check/)

### Inadequate Session Management
- **Location**: Authentication flow in `/lib/auth/auth_gate.dart`
- **Description**: Session management has some issues, including a lack of clear timeout policies and insufficient handling of session invalidation.
- **Impact**: Potential for unauthorized access if devices are shared or stolen.
- **Remediation Checklist**:
  - [ ] Implement proper session timeout mechanisms
  - [ ] Provide options to logout from all devices
  - [ ] Clear sensitive data from memory when sessions end
  - [ ] Invalidate sessions on the server when users log out
- **References**: [OWASP Session Management Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Session_Management_Cheat_Sheet.html)

### Limited Protection Against Reverse Engineering
- **Location**: Application-wide
- **Description**: The application contains hardcoded values and lacks obfuscation, making it easier to reverse engineer.
- **Impact**: Increased risk of intellectual property theft or discovery of security vulnerabilities.
- **Remediation Checklist**:
  - [ ] Implement code obfuscation for production builds
  - [ ] Use Flutter's built-in obfuscation features
  - [ ] Remove debug information from production builds
  - [ ] Consider implementing root/jailbreak detection
- **References**: [OWASP Mobile Top 10 - M8: Code Tampering](https://owasp.org/www-project-mobile-top-10/2016-risks/m8-code-tampering)

## General Security Recommendations
- [ ] Implement a secure Software Development Lifecycle (SDLC)
- [ ] Conduct regular security assessments and penetration testing
- [ ] Develop a security incident response plan
- [ ] Implement proper logging and monitoring
- [ ] Train developers on secure coding practices
- [ ] Setup automated security scanning in CI/CD pipeline
- [ ] Establish clear security requirements and policies
- [ ] Implement a bug bounty program or vulnerability disclosure policy
- [ ] Conduct regular code reviews with security focus

## Security Posture Improvement Plan
1. Address critical vulnerabilities immediately (hardcoded credentials, sensitive data storage)
2. Implement proper input validation and error handling across the application
3. Improve network security with HTTPS enforcement and certificate validation
4. Enhance data protection with encryption and secure storage
5. Update outdated dependencies and implement dependency management strategy
6. Implement code obfuscation and anti-tampering measures
7. Conduct thorough security testing after implementing fixes
8. Establish ongoing security monitoring and incident response capabilities 