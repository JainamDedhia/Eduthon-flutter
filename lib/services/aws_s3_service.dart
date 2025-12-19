import 'dart:convert';
import 'package:crypto/crypto.dart';
import '../config/aws_config.dart';

/// AWS S3 Service
/// Handles S3 operations including signed URL generation
class AwsS3Service {
  /// Generate a presigned URL for S3 object access
  /// 
  /// [objectKey] - The S3 object key (e.g., "Model-2.0+(1).7z")
  /// [expirationHours] - URL expiration time in hours (default: 1 hour)
  /// 
  /// Returns a presigned URL that can be used to download the object
  static String generatePresignedUrl(
    String objectKey, {
    int expirationHours = 1,
  }) {
    final now = DateTime.now().toUtc();
    
    // Format dates for AWS signature
    final dateStamp = _formatDate(now, 'yyyymmdd');
    final amzDate = _formatDate(now, 'yyyymmddThhmmss') + 'Z';
    final expirationSeconds = expirationHours * 3600; // Convert hours to seconds
    
    // URL encode the object key (handle special characters like +)
    final encodedKey = _urlEncode(objectKey, encodeSlash: false);
    
    // Build canonical request
    final canonicalUri = '/$encodedKey';
    final canonicalQueryString = _buildCanonicalQueryString(
      dateStamp,
      amzDate,
      expirationSeconds,
    );
    final canonicalHeaders = _buildCanonicalHeaders(amzDate);
    final signedHeaders = 'host';
    final payloadHash = _sha256(utf8.encode(''));
    
    final canonicalRequest = [
      'GET',
      canonicalUri,
      canonicalQueryString,
      canonicalHeaders,
      '',
      signedHeaders,
      payloadHash,
    ].join('\n');
    
    // Build string to sign
    final algorithm = 'AWS4-HMAC-SHA256';
    final credentialScope = '$dateStamp/${AwsConfig.region}/s3/aws4_request';
    final stringToSign = [
      algorithm,
      amzDate,
      credentialScope,
      _sha256(utf8.encode(canonicalRequest)),
    ].join('\n');
    
    // Calculate signature
    final signature = _calculateSignature(
      stringToSign,
      dateStamp,
    );
    
    // Build presigned URL
    final baseUrl = AwsConfig.getBaseUrl();
    final queryParams = canonicalQueryString +
        '&X-Amz-Signature=$signature';
    
    return '$baseUrl$encodedKey?$queryParams';
  }
  
  /// Build canonical query string for presigned URL
  static String _buildCanonicalQueryString(
    String dateStamp,
    String amzDate,
    int expirationSeconds,
  ) {
    final params = {
      'X-Amz-Algorithm': 'AWS4-HMAC-SHA256',
      'X-Amz-Credential': _buildCredential(dateStamp),
      'X-Amz-Date': amzDate,
      'X-Amz-Expires': expirationSeconds.toString(),
      'X-Amz-SignedHeaders': 'host',
    };
    
    // Sort parameters by key
    final sortedKeys = params.keys.toList()..sort();
    return sortedKeys
        .map((key) => '$key=${_urlEncode(params[key]!)}')
        .join('&');
  }
  
  /// Build credential string
  static String _buildCredential(String dateStamp) {
    final credential = '${AwsConfig.accessKeyId}/$dateStamp/${AwsConfig.region}/s3/aws4_request';
    return _urlEncode(credential);
  }
  
  /// Build canonical headers
  static String _buildCanonicalHeaders(String amzDate) {
    final host = AwsConfig.getServiceEndpoint();
    return 'host:$host\n';
  }
  
  /// Calculate AWS Signature Version 4 signature
  static String _calculateSignature(
    String stringToSign,
    String dateStamp,
  ) {
    // Get signing key
    final kDate = _hmacSha256(
      utf8.encode('AWS4${AwsConfig.secretAccessKey}'),
      utf8.encode(dateStamp),
    );
    final kRegion = _hmacSha256(kDate, utf8.encode(AwsConfig.region));
    final kService = _hmacSha256(kRegion, utf8.encode('s3'));
    final kSigning = _hmacSha256(kService, utf8.encode('aws4_request'));
    
    // Calculate signature
    final signature = _hmacSha256(kSigning, utf8.encode(stringToSign));
    return _bytesToHex(signature);
  }
  
  /// HMAC-SHA256
  static List<int> _hmacSha256(List<int> key, List<int> data) {
    final hmac = Hmac(sha256, key);
    return hmac.convert(data).bytes;
  }
  
  /// SHA256 hash
  static String _sha256(List<int> data) {
    final bytes = sha256.convert(data).bytes;
    return _bytesToHex(bytes);
  }
  
  /// Convert bytes to hexadecimal string
  static String _bytesToHex(List<int> bytes) {
    return bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
  }
  
  /// Format date for AWS
  static String _formatDate(DateTime date, String format) {
    if (format == 'yyyymmdd') {
      return date.year.toString().padLeft(4, '0') +
          date.month.toString().padLeft(2, '0') +
          date.day.toString().padLeft(2, '0');
    } else if (format == 'yyyymmddThhmmss') {
      return _formatDate(date, 'yyyymmdd') +
          'T' +
          date.hour.toString().padLeft(2, '0') +
          date.minute.toString().padLeft(2, '0') +
          date.second.toString().padLeft(2, '0');
    }
    return '';
  }
  
  /// URL encode string (AWS S3 style)
  static String _urlEncode(String input, {bool encodeSlash = true}) {
    final encoded = StringBuffer();
    for (final char in input.codeUnits) {
      if ((char >= 48 && char <= 57) || // 0-9
          (char >= 65 && char <= 90) || // A-Z
          (char >= 97 && char <= 122) || // a-z
          char == 45 || // -
          char == 46 || // .
          char == 95 || // _
          char == 126) { // ~
        encoded.writeCharCode(char);
      } else if (char == 47) { // /
        if (encodeSlash) {
          encoded.write('%2F');
        } else {
          encoded.writeCharCode(char);
        }
      } else {
        // Percent encode
        encoded.write('%${char.toRadixString(16).toUpperCase().padLeft(2, '0')}');
      }
    }
    return encoded.toString();
  }
  
  /// Generate public URL (for public buckets)
  /// This is a simpler method that doesn't require signing
  static String generatePublicUrl(String objectKey) {
    return AwsConfig.buildUrl(objectKey);
  }
}

