extension ShadowEncoder.Sink {
    /// The encoder buffer caching the half-encoded CSV rows.
    internal final class Buffer {
        /// The buffering strategy.
        let strategy: Strategy.EncodingBuffer
        /// The number of expectedFields
        private let expectedFields: Int
        /// The underlying storage.
        private var storage: [Int: [Int:String]]
        
        /// Designated initializer.
        init(strategy: Strategy.EncodingBuffer, expectedFields: Int) {
            self.strategy = strategy
            self.expectedFields = (expectedFields > 0) ? expectedFields : 8
            
            let capacity: Int
            switch strategy {
            case .keepAll:    capacity = 256
            case .assembled:  capacity = 16
            case .sequential: capacity = 2
            }
            self.storage = .init(minimumCapacity: capacity)
        }
    }
}

extension ShadowEncoder.Sink.Buffer {
    /// The number of rows being hold by the receiving buffer.
    var count: Int {
        self.storage.count
    }
    
    /// Returns the number of fields that have been received for the given row.
    /// - parameter rowIndex: The position for the row being targeted.
    func fieldCount(for rowIndex: Int) -> Int {
        self.storage[rowIndex]?.count ?? 0
    }
    
    /// Stores the provided `value` into the temporary storage associating its position as `rowIndex` and `fieldIndex`.
    ///
    /// If there was a value at that position, the value is overwritten.
    /// - parameter value: The new value to store as the field value.
    /// - parameter rowIndex: The position for the row being targeted.
    /// - parameter fieldIndex: The position for the field being targeted.
    func store(value: String, at rowIndex: Int, _ fieldIndex: Int) {
        var fields = self.storage[rowIndex] ?? Dictionary(minimumCapacity: self.expectedFields)
        fields[fieldIndex] = value
        self.storage[rowIndex] = fields
    }
    
    /// Retrieves and removes from the buffer the indicated value.
    /// - parameter rowIndex: The position for the row being targeted.
    /// - parameter fieldIndex: The position for the field being targeted.
    func retrieveField(at rowIndex: Int, _ fieldIndex: Int) -> String? {
        self.storage[rowIndex]?.removeValue(forKey: fieldIndex)
    }
    
    /// Retrieves and removes from the buffer the row at the given position.
    func retrieveRow(at rowIndex: Int) -> Row? {
        guard let fields = self.storage[rowIndex] else { return nil }
        return Row(index: rowIndex, storage: fields)
    }
    
    /// Retrieves and removes from the buffer all rows/fields.
    /// - returns: The sequence accessing all previously stored rows in order.
    func retrieveAll() -> File {
        let sequence = File(storage: self.storage)
        self.storage.removeAll(keepingCapacity: false)
        return sequence
    }
}

extension ShadowEncoder.Sink.Buffer {
    /// Sequence of CSV rows with the rows that the user has set.
    struct File: Sequence, IteratorProtocol {
        /// The buffer storage outcome after being passed by an inversed sort algorithm.
        private var inverseSort: [(key: Int, value: [Int:String])]
        /// Designated initializer taking the buffer storage.
        init(storage: [Int:[Int:String]]) {
            self.inverseSort = storage.sorted { $0.key > $1.key }
        }
        /// The location for the first CSV field stored within this structure.
        var firstIndex: (row: Int, field: Int)? {
            guard let row = self.inverseSort.last else { return nil }
            guard let fieldIndex = row.value.keys.sorted().first else { fatalError() }
            return (row.key, fieldIndex)
        }
        
        mutating func next() -> Row? {
            guard !self.inverseSort.isEmpty else { return nil }
            let element = self.inverseSort.removeLast()
            return Row(index: element.key, storage: element.value)
        }
    }

    /// CSV row with a position index and the fields that the user has set.
    struct Row: Sequence, IteratorProtocol {
        /// The position where the CSV row fits within a CSV file.
        let index: Int
        /// The buffer storage (for a row) after being passed by an inversed sort algorithm.
        private var inverseSort: [(key: Int, value: String)]
        /// Designated initializer taking the buffer storage.
        init(index: Int, storage: [Int:String]) {
            self.index = index
            self.inverseSort = storage.sorted { $0.key > $1.key }
        }
        
        mutating func next() -> Field? {
            guard !self.inverseSort.isEmpty else { return nil }
            let element = self.inverseSort.removeLast()
            return Field(index: element.key, value: element.value)
        }
    }
    
    /// CSV field with a position index and a value that the user has set.
    struct Field {
        /// The position where the CSV fields fits within a row.
        let index: Int
        /// The value to be written.
        let value: String
    }
}
