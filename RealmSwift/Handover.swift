////////////////////////////////////////////////////////////////////////////
//
// Copyright 2014 Realm Inc.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//
////////////////////////////////////////////////////////////////////////////

import Realm

#if swift(>=3.0)
    
/// An object that can be handed over between threads
@objc public protocol ThreadConfined {
    // Runtime-enforced requirement that type also conforms to `_ThreadConfined`
}

// Conformance to `_ThreadConfined` by `ThreadConfined` types cannot be verified by the typechecker or tests
internal protocol _ThreadConfined {
    var realm: Realm? { get }
    var bridgedData: RLMThreadConfined { get }
    var bridgedMetadata: Any? { get }
    static func bridge(data: RLMThreadConfined, metadata: Any?) -> Self
}

extension ThreadConfined {
    internal var _private: _ThreadConfined {
        if let object = self as? _ThreadConfined {
            return object
        } else {
            fatalError("Illegal custom conformances to `RLMThreadConfined` by \(self.dynamicType)")
        }
    }

    static internal var _private: _ThreadConfined.Type {
        if let type = self as? _ThreadConfined.Type {
            return type
        } else {
            fatalError("Illegal custom conformances to `RLMThreadConfined` by \(self)")
        }
    }

    /// The `Realm` the object is associated with
    // Note: cannot be a protocol requirement since `Realm` is not an Objective-C type.
    public var realm: Realm? {
        return _private.realm
    }
}

public class HandoverPackage<T: ThreadConfined> {
    private var metadata: [Any?]
    private var types: [ThreadConfined.Type]
    private let package: RLMHandoverPackage

    internal init(realm: Realm, objects: [T]) {
        self.metadata = objects.map { $0._private.bridgedMetadata }
        self.types = objects.map { $0.dynamicType }
        self.package = realm.rlmRealm.exportForThreadHandover(objects.map { $0._private.bridgedData })
    }

    public func importOnCurrentThead() throws -> (Realm, [T]) {
        defer {
            metadata = []
            types = []
        }

        let handoverImport = try package.importOnCurrentThread()
        // Swift Arrays must be properly typed on index access, and `Object` does not conform to `RLMThreadConfined`
        let handoverables = unsafeBitCast(handoverImport.objects, to: [AnyObject].self)

        let objects: [T] = zip(types, zip(handoverables, metadata)).map { type, arguments in
            let handoverable = unsafeBitCast(arguments.0, to: RLMThreadConfined.self)
            let metadata = arguments.1
            return type._private.bridge(data: handoverable, metadata: metadata) as! T
        }
        return (Realm(handoverImport.realm), objects)
    }
}

#else

/// An object that can be handed over between threads
@objc public protocol ThreadConfined {
    // Runtime-enforced requirement that type also conforms to `_ThreadConfined`
}

// Conformance to `_ThreadConfined` by `ThreadConfined` types cannot be verified by the typechecker or tests
internal protocol _ThreadConfined {
    var realm: Realm? { get }
    var bridgedData: RLMThreadConfined { get }
    var bridgedMetadata: Any? { get }
    static func bridge(data: RLMThreadConfined, metadata: Any?) -> Self
}

extension ThreadConfined {
    internal var _private: _ThreadConfined {
        if let object = self as? _ThreadConfined {
            return object
        } else {
            fatalError("Illegal custom conformances to `RLMThreadConfined` by \(self.dynamicType)")
        }
    }

    static internal var _private: _ThreadConfined.Type {
        if let type = self as? _ThreadConfined.Type {
            return type
        } else {
            fatalError("Illegal custom conformances to `RLMThreadConfined` by \(self)")
        }
    }

    /// The `Realm` the object is associated with
    // Note: cannot be a protocol requirement since `Realm` is not an Objective-C type.
    public var realm: Realm? {
        return _private.realm
    }
}

public class HandoverPackage<T: ThreadConfined> {
    private var metadata: [Any?]
    private var types: [ThreadConfined.Type]
    private let package: RLMHandoverPackage

    internal init(realm: Realm, objects: [T]) {
        self.metadata = objects.map { $0._private.bridgedMetadata }
        self.types = objects.map { $0.dynamicType }
        self.package = realm.rlmRealm.exportForThreadHandover(objects.map { $0._private.bridgedData })
    }

    public func importOnCurrentThead() throws -> (Realm, [T]) {
        defer {
            metadata = []
            types = []
        }

        let handoverImport = try package.importOnCurrentThread()
        // Swift Arrays must be properly typed on index access, and `Object` does not conform to `RLMThreadConfined`
        let handoverables = unsafeBitCast(handoverImport.objects, [AnyObject].self)

        let objects: [T] = zip(types, zip(handoverables, metadata)).map { type, arguments in
            let handoverable = unsafeBitCast(arguments.0, RLMThreadConfined.self)
            let metadata = arguments.1
            return type._private.bridge(handoverable, metadata: metadata) as! T
        }
        return (Realm(handoverImport.realm), objects)
    }
}

#endif
