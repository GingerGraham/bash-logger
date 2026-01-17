# Security Policy

## Supported Versions

We provide security updates for the following versions:

| Version | Supported          |
| ------- | ------------------ |
| 1.0.x   | :white_check_mark: |
| 0.10.x  | :x:                |
| 0.9.x   | :x:                |
| < 0.9   | :x:                |

## Reporting a Vulnerability

If you discover a security vulnerability in bash-logger, please report it **privately** to help protect users.

### How to Report

1. **Do NOT open a public issue** for security vulnerabilities
2. Instead, use GitHub's private vulnerability reporting:
   * Go to the [Security tab](https://github.com/GingerGraham/bash-logger/security)
   * Click "Report a vulnerability"
   * Provide detailed information about the issue

Alternatively, you can email the maintainer directly (see GitHub profile for contact information).

### What to Include

* Description of the vulnerability
* Steps to reproduce the issue
* Potential impact and severity
* Any suggested fixes or mitigations (if applicable)
* Your preferred method of acknowledgment (if desired)

### Response Timeline

* **Initial Response**: Within 5 business days
* **Status Update**: Within 10 business days
* **Fix Timeline**: Depends on severity
  * Critical: 7-14 days
  * High: 14-30 days
  * Medium/Low: 30-90 days

## Security Considerations for Users

### Sensitive Data Handling

bash-logger includes a special function for handling sensitive information:

```bash
log_sensitive "Password: $secret"  # Only to console, never logged to file/journal
```

**Important**: Regular log functions (`log_info`, `log_debug`, etc.) will write to files and journals. Never log passwords, API keys, or other secrets using standard log functions.

See [Sensitive Data Documentation](docs/sensitive-data.md) for details.

### Log File Permissions

Log files may contain sensitive information. Always set appropriate permissions:

```bash
# Set restrictive permissions on log files
chmod 600 /var/log/myapp.log
chown myuser:mygroup /var/log/myapp.log

# Or create with secure permissions
touch /var/log/myapp.log
chmod 600 /var/log/myapp.log
```

Consider using log rotation with proper permission handling (e.g., `logrotate` with `create` directive).

### Configuration File Security

Configuration files may contain paths and settings that reveal system information:

```bash
# Protect configuration files
chmod 640 /etc/myapp/logging.conf
chown root:mygroup /etc/myapp/logging.conf
```

### Command Injection Prevention

bash-logger does **not** execute user-provided strings as commands. However, if you log user input, be aware of:

* **Log injection**: User input containing newlines can create fake log entries
* **Terminal escape sequences**: Malicious sequences in logged data could affect terminal viewers

**Mitigation**:

```bash
# Sanitize user input before logging
user_input="${user_input//[$'\n\r']/}"  # Remove newlines
log_info "User provided: ${user_input}"
```

### Journal Logging Security

When using systemd journal integration:

* Journal entries are visible to users in the `systemd-journal` group
* Consider journal access permissions for sensitive applications
* Use `--tag` to help with filtering and access control
* Review `journalctl` access controls in your environment

### Script Source Verification

When sourcing the logging module, verify its integrity:

```bash
# Verify checksum before sourcing (in production)
expected_checksum="..."
actual_checksum=$(sha256sum /path/to/logging.sh | cut -d' ' -f1)

if [[ "$actual_checksum" != "$expected_checksum" ]]; then
    echo "ERROR: logging.sh checksum mismatch!" >&2
    exit 1
fi

source /path/to/logging.sh
```

### File Path Traversal

If you accept log file paths from user input or configuration:

```bash
# Validate log file path
log_file="$1"
if [[ "$log_file" == *".."* ]] || [[ "$log_file" != /* ]]; then
    echo "ERROR: Invalid log file path" >&2
    exit 1
fi

init_logger --log "$log_file"
```

## Known Security Considerations

### Not Applicable to bash-logger

The following common security concerns are **not** applicable:

* **SQL Injection**: bash-logger does not interact with databases
* **XSS/CSRF**: bash-logger is not a web application
* **Remote Code Execution**: bash-logger does not accept or execute remote code
* **Authentication/Authorization**: bash-logger does not implement access control (relies on OS permissions)

### Dependencies

bash-logger has **no external dependencies** except:

* Bash 4.0 or later
* Standard Unix utilities (cat, grep, wc, date, etc.)
* Optional: `logger` command for journal integration (part of util-linux)

This minimal dependency surface reduces supply chain risk.

## Security Best Practices

When using bash-logger in your applications:

1. **Never log sensitive data** with standard functions
2. **Set restrictive permissions** on log files (600 or 640)
3. **Validate user input** before logging
4. **Review journal access** if using systemd integration
5. **Rotate logs** to prevent information accumulation
6. **Sanitize log output** when displaying to users
7. **Use version control** to track changes to logging.sh
8. **Test in staging** before deploying changes

## Acknowledgments

We appreciate responsible disclosure of security issues. Contributors who report valid security vulnerabilities will be acknowledged (with permission) in:

* The security advisory
* The CHANGELOG for the fix release
* This SECURITY.md file (if desired)

## Additional Resources

* [OWASP Logging Cheat Sheet](https://cheatsheetsecurity.org/cheatsheets/logging-vocabulary-cheat-sheet.html)
* [Systemd Journal Security](https://www.freedesktop.org/software/systemd/man/systemd-journald.service.html)
* [Bash Security Best Practices](https://mywiki.wooledge.org/BashGuide/Practices)

---

Thank you for helping keep bash-logger and its users secure!
