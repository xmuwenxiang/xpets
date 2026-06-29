import Foundation
import simd
import DPFoundation

/// A pure-Swift minimal GLB parser sufficient for Spec-005's test fixture.
///
/// GLB layout reference:
///   Header: 12 bytes — magic 'glTF', version u32, length u32
///   Chunk 0 (JSON): 8-byte header + JSON
///   Chunk 1 (BIN): 8-byte header + binary buffer
///
/// The JSON header carries a `nodes`, `meshes.primitives[].attributes.JOINTS_0/WEIGHTS_0`,
/// `skins`, `animations`, and `accessors` referencing the BIN chunk via
/// `bufferView` indices. We extract whichever fields the test fixture actually uses;
/// the loader is unit-tested with frozen input so drift fails integration.
public enum GLBDecoder {
    public static func decode(url: URL) throws -> GLBAsset {
        let data: Data
        do { data = try Data(contentsOf: url) } catch {
            throw AssetError.ioError(underlying: "\(error)")
        }
        return try decode(data: data)
    }

    public static func decode(data: Data) throws -> GLBAsset {
        guard data.count >= 12 else {
            throw AssetError.decodeError(reason: "data shorter than GLB header")
        }
        // Header: uint32 magic + uint32 version + uint32 length
        let magic = data.subdata(in: 0..<4)
        guard magic == Data([0x67, 0x6C, 0x54, 0x46]) else {
            throw AssetError.decodeError(reason: "bad GLB magic")
        }
        let version: UInt32 = data.loadU32(at: 4)
        guard version == 2 else {
            throw AssetError.unsupportedVersion(major: Int(version), minor: 0)
        }
        let totalLength: UInt32 = data.loadU32(at: 8)
        if Int(totalLength) > data.count {
            throw AssetError.decodeError(reason: "GLB total length exceeds data size")
        }

        // Chunk 0 (JSON)
        guard data.count >= 20 else { throw AssetError.decodeError(reason: "no JSON chunk header") }
        let chunk0Length: UInt32 = data.loadU32(at: 12)
        guard chunk0Length > 0 else { throw AssetError.decodeError(reason: "zero JSON chunk") }
        let chunk0Type: UInt32 = data.loadU32(at: 16)
        guard chunk0Type == 0x4E4F534A else {   // "JSON" as little-endian u32
            throw AssetError.decodeError(reason: "first chunk is not JSON")
        }
        let jsonStart = 20
        let jsonEnd = jsonStart + Int(chunk0Length)
        guard jsonEnd <= data.count else { throw AssetError.decodeError(reason: "JSON chunk overruns") }
        let jsonData = data.subdata(in: jsonStart..<jsonEnd)

        // Optional BIN chunk
        var binData: Data = Data()
        var cursor = jsonEnd
        if cursor + 8 <= data.count {
            let chunk1Length: UInt32 = data.loadU32(at: cursor)
            let chunk1Type: UInt32 = data.loadU32(at: cursor + 4)
            if chunk1Type == 0x004E4942 {    // "BIN\0"
                cursor += 8
                let binEnd = cursor + Int(chunk1Length)
                guard binEnd <= data.count else { throw AssetError.decodeError(reason: "BIN overruns") }
                binData = data.subdata(in: cursor..<binEnd)
            }
        }

        let json = try JSONSerialization.jsonObject(with: jsonData, options: [])
        guard let root = json as? [String: Any] else {
            throw AssetError.schemaMismatch(field: "glb.root", expected: "object", actual: String(describing: type(of: json)))
        }

        return try parse(root: root, bin: binData)
    }

    // MARK: - JSON → Asset
    private static func parse(root: [String: Any], bin: Data) throws -> GLBAsset {
        let nodes = (root["nodes"] as? [[String: Any]]) ?? []
        let skins = (root["skins"] as? [[String: Any]]) ?? []
        let meshes = (root["meshes"] as? [[String: Any]]) ?? []
        let accessors = (root["accessors"] as? [[String: Any]]) ?? []
        let bufferViews = (root["bufferViews"] as? [[String: Any]]) ?? []
        let anims = (root["animations"] as? [[String: Any]]) ?? []
        let materialsJSON = (root["materials"] as? [[String: Any]]) ?? []
        let texturesJSON = (root["textures"] as? [[String: Any]]) ?? []
        let imagesJSON = (root["images"] as? [[String: Any]]) ?? []

        // -------- Skeleton --------
        // Materialize from the first skin we encounter. The Spec-005 fixture ships exactly one.
        var bones: [BoneData] = []
        var parents: [Int] = []
        var inverseBindMatrices: [Float4x4] = []
        if let skin = skins.first {
            let joints = (skin["joints"] as? [Int]) ?? []
            for (idx, _) in nodes.enumerated() where joints.contains(idx) {
                let nm = (nodes[idx]["name"] as? String) ?? "joint_\(idx)"
                bones.append(BoneData(id: idx, name: nm))
                parents.append(findParent(nodes: nodes, childIndex: idx))
            }
            if let ibmAcc = skin["inverseBindMatrices"] as? Int,
               let ibms = try? readMatrices(accessorIndex: ibmAcc, accessors: accessors, bufferViews: bufferViews, bin: bin) {
                inverseBindMatrices = ibms
            }
        }

        // Rest pose: bind matrices × inverse bind matrices (when IBM is available);
        // otherwise identity with root translation = (0,g,0).
        var restPose: [Float4x4] = []
        if !inverseBindMatrices.isEmpty {
            for (b, _) in bones.enumerated() {
                if b < inverseBindMatrices.count {
                    // Rest pose = inverseBind^-1; store matrix form.
                    restPose.append(inverseBindMatrices[b].inverse)
                } else {
                    restPose.append(identityFloat4x4)
                }
            }
        } else {
            for bone in bones {
                let node = nodes[bone.id]
                let t = translateFrom(node)
                restPose.append(SimdBuilders.translation(t))
            }
        }

        let skeleton = SkeletonData(bones: bones, parents: parents, restPose: restPose)

        // -------- Mesh --------
        // Phase 1 only consumes one mesh with POSITION + JOINTS_0 + WEIGHTS_0.
        var mesh = SkinnedMesh(vertexCount: 0, indexCount: 0, jointIndices: [], jointWeights: [])
        if let meshEntry = meshes.first {
            guard let primitives = meshEntry["primitives"] as? [[String: Any]], let prim = primitives.first else {
                throw AssetError.schemaMismatch(field: "meshes.primitives", expected: "non-empty array", actual: nil)
            }
            guard let attrs = prim["attributes"] as? [String: Any] else {
                throw AssetError.schemaMismatch(field: "primitives.attributes", expected: "object", actual: nil)
            }

            // Vertex count from the POSITION accessor
            if let positionIdx = attrs["POSITION"] as? Int,
               positionIdx < accessors.count,
               let cnt = accessors[positionIdx]["count"] as? Int {
                mesh.vertexCount = cnt
            }

            if let indicesAcc = prim["indices"] as? Int,
               let cnt = accessors[safe: indicesAcc]?["count"] as? Int {
                mesh.indexCount = cnt
            }

            if let jointsAccIdx = attrs["JOINTS_0"] as? Int,
               let weightsAccIdx = attrs["WEIGHTS_0"] as? Int {
                mesh.jointIndices = try readJointIndices(accessorIndex: jointsAccIdx, accessors: accessors, bufferViews: bufferViews, bin: bin, vertexCount: mesh.vertexCount)
                mesh.jointWeights = try readJointWeights(accessorIndex: weightsAccIdx, accessors: accessors, bufferViews: bufferViews, bin: bin, vertexCount: mesh.vertexCount)
            }

            if let posIdx = attrs["POSITION"] as? Int, posIdx < accessors.count {
                mesh.positions = try readPositions(accessorIndex: posIdx, accessors: accessors, bufferViews: bufferViews, bin: bin, vertexCount: mesh.vertexCount)
            }
            if let uvIdx = attrs["TEXCOORD_0"] as? Int, uvIdx < accessors.count {
                mesh.texcoords = try readTexcoords(accessorIndex: uvIdx, accessors: accessors, bufferViews: bufferViews, bin: bin, vertexCount: mesh.vertexCount)
            }
            if let idxAcc = prim["indices"] as? Int, idxAcc < accessors.count {
                mesh.indices = try readIndices(accessorIndex: idxAcc, accessors: accessors, bufferViews: bufferViews, bin: bin)
            }
        }

        // -------- Animations --------
        var animations: [AnimationData] = []
        for anim in anims {
            let name = (anim["name"] as? String) ?? "Idle"
            let channels = (anim["channels"] as? [[String: Any]]) ?? []
            var chans: [AnimationChannel] = []
            for ch in channels {
                guard let samplerIdx = ch["sampler"] as? Int,
                      let target = ch["target"] as? [String: Any],
                      let nodeIdx = target["node"] as? Int,
                      let propertyStr = target["path"] as? String,
                      let property = AnimationChannel.Property(rawValue: propertyStr),
                      let samplers = anim["samplers"] as? [[String: Any]],
                      samplerIdx < samplers.count,
                      let inputAcc = samplers[samplerIdx]["input"] as? Int,
                      let outputAcc = samplers[samplerIdx]["output"] as? Int else {
                    throw AssetError.schemaMismatch(field: "animations.channels", expected: "sampler inputs/outputs", actual: nil)
                }
                _ = property  // Canonical lookup deferred to readKeyframeValues via .canonical().
                let keyframes: [Keyframe] = try buildKeyframes(
                    property: property,
                    boneIndex: bones.firstIndex(where: { $0.id == nodeIdx }) ?? -1,
                    inputAcc: inputAcc,
                    outputAcc: outputAcc,
                    accessors: accessors,
                    bufferViews: bufferViews,
                    bin: bin
                )
                chans.append(AnimationChannel(boneIndex: bones.firstIndex(where: { $0.id == nodeIdx }) ?? nodeIdx, property: property, keyframes: keyframes))
            }
            // Compute duration from max keyframe time.
            let maxTime = chans.flatMap { $0.keyframes.map { $0.time } }.max() ?? 0
            // Loop flag: spec-005 risk notes non-loop must log+warp; Phase 1 assumes
            // looping for all single-clip cases unless the JSON says otherwise.
            let looping: Bool
            if let l = anim["loop"] as? Bool {
                looping = l
            } else if let wrap = anim["wrap"] as? String {
                looping = (wrap == "loop")
            } else {
                looping = true
            }
            animations.append(AnimationData(name: name, duration: maxTime, channels: chans, looping: looping))
        }

        // -------- Materials + Images (2a) --------
        var materials: [MaterialData] = []
        for (i, m) in materialsJSON.enumerated() {
            let name = (m["name"] as? String) ?? "material_\(i)"
            let pbr = (m["pbrMetallicRoughness"] as? [String: Any]) ?? [:]
            let metallicFactor = Float((pbr["metallicFactor"] as? Double) ?? 0)
            let roughnessFactor = Float((pbr["roughnessFactor"] as? Double) ?? 1)
            var albedoImageIndex: Int? = nil
            if let bct = pbr["baseColorTexture"] as? [String: Any],
               let texIdx = bct["index"] as? Int,
               texIdx < texturesJSON.count {
                albedoImageIndex = texturesJSON[texIdx]["source"] as? Int
            }
            materials.append(MaterialData(name: name, albedoImageIndex: albedoImageIndex,
                                          metallicFactor: metallicFactor, roughnessFactor: roughnessFactor))
        }

        var images: [DecodedImage] = []
        for im in imagesJSON {
            guard let bvIdx = im["bufferView"] as? Int, bvIdx < bufferViews.count else { continue }
            let bv = bufferViews[bvIdx]
            let offset = (bv["byteOffset"] as? Int) ?? 0
            let length = (bv["byteLength"] as? Int) ?? 0
            let end = offset + length
            guard length > 0, end <= bin.count else { continue }
            let imgData = bin.subdata(in: offset..<end)
            if let decoded = PNGDecoder.decode(imgData) { images.append(decoded) }
        }

        return GLBAsset(mesh: mesh, skeleton: skeleton, animations: animations, textures: [],
                        materials: materials, images: images)
    }

    // MARK: - Helpers
    private static func findParent(nodes: [[String: Any]], childIndex: Int) -> Int {
        for (i, n) in nodes.enumerated() {
            if let children = n["children"] as? [Int], children.contains(childIndex) {
                return i
            }
            if let children = n["children"] as? [Int] {
                for c in children where c == childIndex { return i }
            }
        }
        return -1
    }

    private static func translateFrom(_ node: [String: Any]) -> Float3 {
        guard let t = node["translation"] as? [Double], t.count == 3 else { return .zero }
        return Float3(Float(t[0]), Float(t[1]), Float(t[2]))
    }

    private static func readMatrices(accessorIndex: Int, accessors: [[String: Any]], bufferViews: [[String: Any]], bin: Data) throws -> [Float4x4] {
        let acc = accessors[accessorIndex]
        guard let bvIdx = acc["bufferView"] as? Int else { return [] }
        return try readMatrices(bufferViewIndex: bvIdx, bufferViews: bufferViews, bin: bin)
    }

    private static func readMatrices(bufferViewIndex: Int, bufferViews: [[String: Any]], bin: Data) throws -> [Float4x4] {
        let bv = bufferViews[bufferViewIndex]
        let offset = (bv["byteOffset"] as? Int) ?? 0
        let length = (bv["byteLength"] as? Int) ?? 0
        let cnt = length / MemoryLayout<Float>.size / 16
        var matrices: [Float4x4] = []
        for i in 0..<cnt {
            let off = offset + i * 64
            if off + 64 > bin.count { break }
            var m = matrix_identity_float4x4
            m.columns.0 = Float4(bin.loadF(at: off), bin.loadF(at: off+4), bin.loadF(at: off+8), bin.loadF(at: off+12))
            m.columns.1 = Float4(bin.loadF(at: off+16), bin.loadF(at: off+20), bin.loadF(at: off+24), bin.loadF(at: off+28))
            m.columns.2 = Float4(bin.loadF(at: off+32), bin.loadF(at: off+36), bin.loadF(at: off+40), bin.loadF(at: off+44))
            m.columns.3 = Float4(bin.loadF(at: off+48), bin.loadF(at: off+52), bin.loadF(at: off+56), bin.loadF(at: off+60))
            matrices.append(m)
        }
        return matrices
    }

    private static func readJointIndices(accessorIndex: Int, accessors: [[String: Any]], bufferViews: [[String: Any]], bin: Data, vertexCount: Int) throws -> [SIMD4<UInt16>] {
        guard let bvIdx = accessors[accessorIndex]["bufferView"] as? Int else {
            return Array(repeating: SIMD4<UInt16>(0,0,0,0), count: vertexCount)
        }
        let bv = bufferViews[bvIdx]
        let offset = (bv["byteOffset"] as? Int) ?? 0
        // Phase 1 assumption: accessor componentType u16 == 5123.
        let componentType = (accessors[accessorIndex]["componentType"] as? Int) ?? 5123
        let stride = componentType == 5126 ? 16 : 8  // u16×4 = 8 bytes, f32×4 = 16 bytes
        var out: [SIMD4<UInt16>] = []
        var pos = offset
        for _ in 0..<vertexCount {
            if pos + stride > bin.count { break }
            switch componentType {
            case 5123:  // unsigned short
                let a = bin.loadU16(at: pos)
                let b = bin.loadU16(at: pos+2)
                let c = bin.loadU16(at: pos+4)
                let d = bin.loadU16(at: pos+6)
                out.append(SIMD4<UInt16>(a, b, c, d))
            case 5126:  // float — allowed but uncommon
                let a = UInt16(bin.loadF(at: pos))
                let b = UInt16(bin.loadF(at: pos+4))
                let c = UInt16(bin.loadF(at: pos+8))
                let d = UInt16(bin.loadF(at: pos+12))
                out.append(SIMD4<UInt16>(a, b, c, d))
            default:
                out.append(SIMD4<UInt16>(0,0,0,0))
            }
            pos += stride
        }
        return out
    }

    private static func readJointWeights(accessorIndex: Int, accessors: [[String: Any]], bufferViews: [[String: Any]], bin: Data, vertexCount: Int) throws -> [SIMD4<Float>] {
        guard let bvIdx = accessors[accessorIndex]["bufferView"] as? Int else {
            return Array(repeating: SIMD4<Float>(0,0,0,0), count: vertexCount)
        }
        let bv = bufferViews[bvIdx]
        let offset = (bv["byteOffset"] as? Int) ?? 0
        // Phase 1 assumes f32.
        let stride = 16
        var out: [SIMD4<Float>] = []
        var pos = offset
        for _ in 0..<vertexCount {
            if pos + stride > bin.count { break }
            let a = bin.loadF(at: pos)
            let b = bin.loadF(at: pos+4)
            let c = bin.loadF(at: pos+8)
            let d = bin.loadF(at: pos+12)
            out.append(SIMD4<Float>(a, b, c, d))
            pos += stride
        }
        return out
    }

    private static func readPositions(accessorIndex: Int, accessors: [[String: Any]], bufferViews: [[String: Any]], bin: Data, vertexCount: Int) throws -> [SIMD3<Float>] {
        guard accessorIndex < accessors.count,
              let bvIdx = accessors[accessorIndex]["bufferView"] as? Int else {
            return Array(repeating: SIMD3<Float>(0,0,0), count: vertexCount)
        }
        let bv = bufferViews[bvIdx]
        let offset = (bv["byteOffset"] as? Int) ?? 0
        var out: [SIMD3<Float>] = []
        var pos = offset
        for _ in 0..<vertexCount {
            if pos + 12 > bin.count { break }
            out.append(SIMD3<Float>(bin.loadF(at: pos), bin.loadF(at: pos+4), bin.loadF(at: pos+8)))
            pos += 12
        }
        return out
    }

    private static func readTexcoords(accessorIndex: Int, accessors: [[String: Any]], bufferViews: [[String: Any]], bin: Data, vertexCount: Int) throws -> [SIMD2<Float>] {
        guard accessorIndex < accessors.count,
              let bvIdx = accessors[accessorIndex]["bufferView"] as? Int else {
            return Array(repeating: SIMD2<Float>(0,0), count: vertexCount)
        }
        let bv = bufferViews[bvIdx]
        let offset = (bv["byteOffset"] as? Int) ?? 0
        var out: [SIMD2<Float>] = []
        var pos = offset
        for _ in 0..<vertexCount {
            if pos + 8 > bin.count { break }
            out.append(SIMD2<Float>(bin.loadF(at: pos), bin.loadF(at: pos+4)))
            pos += 8
        }
        return out
    }

    private static func readIndices(accessorIndex: Int, accessors: [[String: Any]], bufferViews: [[String: Any]], bin: Data) throws -> [UInt32] {
        guard accessorIndex < accessors.count else { return [] }
        let acc = accessors[accessorIndex]
        guard let bvIdx = acc["bufferView"] as? Int, bvIdx < bufferViews.count else { return [] }
        let bv = bufferViews[bvIdx]
        let offset = (bv["byteOffset"] as? Int) ?? 0
        let cnt = (acc["count"] as? Int) ?? 0
        let componentType = (acc["componentType"] as? Int) ?? 5123
        let stride = componentType == 5125 ? 4 : 2   // 5125=uint32, 5123=uint16
        var out: [UInt32] = []
        var pos = offset
        for _ in 0..<cnt {
            if pos + stride > bin.count { break }
            if componentType == 5125 { out.append(bin.loadU32(at: pos)) }
            else { out.append(UInt32(bin.loadU16(at: pos))) }
            pos += stride
        }
        return out
    }

    private static func buildKeyframes(property: AnimationChannel.Property, boneIndex: Int, inputAcc: Int, outputAcc: Int, accessors: [[String: Any]], bufferViews: [[String: Any]], bin: Data) throws -> [Keyframe] {
        let inputs = try readTimes(accessorIndex: inputAcc, accessors: accessors, bufferViews: bufferViews, bin: bin)
        let outputs = try readKeyframeValues(accessorIndex: outputAcc, property: property, accessors: accessors, bufferViews: bufferViews, bin: bin)
        var keyframes: [Keyframe] = []
        for (i, t) in inputs.enumerated() {
            if i < outputs.count {
                keyframes.append(Keyframe(time: t, value: outputs[i]))
            }
        }
        return keyframes
    }

    private static func readTimes(accessorIndex: Int, accessors: [[String: Any]], bufferViews: [[String: Any]], bin: Data) throws -> [Double] {
        let acc = accessors[accessorIndex]
        guard let bvIdx = acc["bufferView"] as? Int else { return [] }
        let bv = bufferViews[bvIdx]
        let offset = (bv["byteOffset"] as? Int) ?? 0
        let cnt = (acc["count"] as? Int) ?? 0
        var out: [Double] = []
        for i in 0..<cnt {
            let pos = offset + i * 4
            if pos + 4 > bin.count { break }
            out.append(Double(bin.loadF(at: pos)))
        }
        return out
    }

    private static func readKeyframeValues(accessorIndex: Int, property: AnimationChannel.Property, accessors: [[String: Any]], bufferViews: [[String: Any]], bin: Data) throws -> [KeyframeValue] {
        let acc = accessors[accessorIndex]
        guard let bvIdx = acc["bufferView"] as? Int else { return [] }
        let bv = bufferViews[bvIdx]
        let offset = (bv["byteOffset"] as? Int) ?? 0
        let cnt = (acc["count"] as? Int) ?? 0
        var out: [KeyframeValue] = []
        switch property.canonical() {
        case .translate:
            for i in 0..<cnt {
                let pos = offset + i * 12
                if pos + 12 > bin.count { break }
                let v = SIMD3<Float>(bin.loadF(at: pos), bin.loadF(at: pos+4), bin.loadF(at: pos+8))
                out.append(.translate(v))
            }
        case .scale:
            for i in 0..<cnt {
                let pos = offset + i * 12
                if pos + 12 > bin.count { break }
                let v = SIMD3<Float>(bin.loadF(at: pos), bin.loadF(at: pos+4), bin.loadF(at: pos+8))
                out.append(.scale(v))
            }
        case .rotate:
            for i in 0..<cnt {
                let pos = offset + i * 16
                if pos + 16 > bin.count { break }
                let x = bin.loadF(at: pos); let y = bin.loadF(at: pos+4)
                let z = bin.loadF(at: pos+8); let w = bin.loadF(at: pos+12)
                out.append(.rotate(simd_quatf(ix: x, iy: y, iz: z, r: w)))
            }
        }
        return out
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

extension Data {
    func loadU32(at offset: Int) -> UInt32 {
        precondition(offset + 4 <= count, "u32 read out of bounds at \(offset)")
        var v: UInt32 = 0
        v |= UInt32(self[offset])
        v |= UInt32(self[offset+1]) << 8
        v |= UInt32(self[offset+2]) << 16
        v |= UInt32(self[offset+3]) << 24
        return v
    }

    func loadU16(at offset: Int) -> UInt16 {
        precondition(offset + 2 <= count, "u16 read out of bounds at \(offset)")
        return UInt16(self[offset]) | (UInt16(self[offset+1]) << 8)
    }

    func loadF(at offset: Int) -> Float {
        precondition(offset + 4 <= count, "f32 read out of bounds at \(offset)")
        var u: UInt32 = 0
        u |= UInt32(self[offset])
        u |= UInt32(self[offset+1]) << 8
        u |= UInt32(self[offset+2]) << 16
        u |= UInt32(self[offset+3]) << 24
        return Float(bitPattern: u)
    }
}
