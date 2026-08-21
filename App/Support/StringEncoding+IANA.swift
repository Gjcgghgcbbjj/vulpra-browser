//
//  StringEncoding+IANA.swift
//  Vulpra
//
//  Ported from the upstream proven baseline.
//

extension String.Encoding {
    static func ianaCharacterSetName(_ name: String) -> String.Encoding? {
        let cfEncoding = CFStringConvertIANACharSetNameToEncoding(name as CFString)
        guard cfEncoding != kCFStringEncodingInvalidId else {
            return nil
        }
        
        let nsEncoding = CFStringConvertEncodingToNSStringEncoding(cfEncoding)
        return String.Encoding(rawValue: nsEncoding)
    }
}
