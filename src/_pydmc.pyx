from cpython cimport array
cimport cpython

import bitarray
import struct
import base64

from libc.string cimport memcpy
cdef array.array char_array_template = array.array('b', [])

cdef extern from "MurmurHash3.h" nogil:
    void MurmurHash3_x64_128(void *key, int len, unsigned int seed, void *out)
    void MurmurHash3_x64_128_long(long key, unsigned int seed, void *out)

def hash(key, int seed=0):
    cdef long long result[2]
    if isinstance(key, unicode):
        key = key.encode('utf8')

    MurmurHash3_x64_128(<char*> key, len(key), seed, result)
    return long(result[0]) << 64 | (long(result[1]) & 0xFFFFFFFFFFFFFFFF)

def hash_long(long long key, int seed=0):
    cdef long long result[2]
    MurmurHash3_x64_128_long(key, seed, &result)
    return long(result[0]) << 64 | (long(result[1]) & 0xFFFFFFFFFFFFFFFF)

cdef char* fmt = '!III'
cdef ssize_t header_size = sizeof(unsigned int) * 3

cdef class _DMC:
    cdef unsigned int _size
    cdef unsigned int _items
    cdef object _bitarray

    def __cinit__(self, unsigned long size, cpython.bool _clear=True, unsigned int _items=0):
        self._size = size
        self._items = _items
        self._bitarray = bitarray.bitarray(size)

        if _clear:
            self._bitarray.setall(False)

    cpdef _from_byte_array(self, array.array byte_array):
        (address, size, endianness, unused, allocated) = self._bitarray.buffer_info()
        memcpy(cpython.PyLong_AsVoidPtr(address), byte_array.data.as_chars + header_size,
               byte_array.ob_size - header_size)

    @classmethod
    def from_byte_array(cls, array.array byte_array):
        assert byte_array.ob_size > header_size
        array_size, bit_size, items = struct.unpack_from(fmt, byte_array)
        assert bit_size / 8 <= array_size
        assert array_size == byte_array.ob_size - header_size
        cdef dmc = cls(bit_size, _clear=False, _items=items)
        dmc._from_byte_array(byte_array)
        return dmc

    def to_byte_array(self):
        (address, size, endianness, unused, allocated) = self._bitarray.buffer_info()
        cdef unsigned int length = size + header_size
        cdef array.array byte_array = array.clone(char_array_template, length, False)
        struct.pack_into(fmt, byte_array, 0, size, self._size, self._items)
        memcpy(byte_array.data.as_chars + header_size, cpython.PyLong_AsVoidPtr(address), size)
        return byte_array

    def to_base64(self):
        return base64.b64encode(self.to_byte_array())

    @classmethod
    def from_base64(cls, bytes s):
        return cls.from_byte_array(array.array('b', base64.b64decode(s)))

    property items:
        def __get__(self):
            return self._items

    property size:
        def __get__(self):
            return self._size

    cpdef clear(self):
        self._items = 0
        self._bitarray.setall(False)

cdef class LongDMC(_DMC):
    cpdef add(self, long long item):
        hash_val = hash_long(item) % self._size
        old_val = self._bitarray[hash_val]
        if not old_val:
            self._items += 1
            self._bitarray[hash_val] = True

    cpdef extend(self, items):
        for item in items:
            hash_val = hash_long(<long long>item) % self._size
            old_val = self._bitarray[hash_val]
            if not old_val:
                self._items += 1
                self._bitarray[hash_val] = True

    cpdef extend_array(self, long long[:] items):
        for item in items:
            hash_val = hash_long(item) % self._size
            old_val = self._bitarray[hash_val]
            if not old_val:
                self._items += 1
                self._bitarray[hash_val] = True

    def __contains__(self, long long item):
        hash_val = hash_long(item) % self._size
        return self._bitarray[hash_val]

cdef class UIntDMC(_DMC):
    cpdef add(self, unsigned int item):
        hash_val = hash_long(item) % self._size
        old_val = self._bitarray[hash_val]
        if not old_val:
            self._items += 1
            self._bitarray[hash_val] = True

    cpdef extend(self, items):
        for item in items:
            hash_val = hash_long(<unsigned int>item) % self._size
            old_val = self._bitarray[hash_val]
            if not old_val:
                self._items += 1
                self._bitarray[hash_val] = True

    cpdef extend_array(self, unsigned int[:] items):
        for item in items:
            hash_val = hash_long(item) % self._size
            old_val = self._bitarray[hash_val]
            if not old_val:
                self._items += 1
                self._bitarray[hash_val] = True

    def __contains__(self, unsigned int item):
        hash_val = hash_long(item) % self._size
        return self._bitarray[hash_val]

cdef class StringDMC(_DMC):
    cpdef add(self, item):
        hash_val = hash(item) % self._size
        old_val = self._bitarray[hash_val]
        if not old_val:
            self._items += 1
            self._bitarray[hash_val] = True

    def __contains__(self, item):
        hash_val = hash(item) % self._size
        return self._bitarray[hash_val]
