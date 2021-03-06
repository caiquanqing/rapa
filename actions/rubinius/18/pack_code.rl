/* This file was generated by Ragel. Your edits will be lost.
 *
 * This is a state machine implementation of Array#pack.
 * See http://github.com/rubinius/rapa.
 *
 * vim: filetype=cpp
 */

#include <stdint.h>
#include <sstream>

#include "vm/config.h"

#include "vm.hpp"
#include "object_utils.hpp"
#include "on_stack.hpp"
#include "objectmemory.hpp"

#include "builtin/array.hpp"
#include "builtin/bytearray.hpp"
#include "builtin/exception.hpp"
#include "builtin/float.hpp"
#include "builtin/module.hpp"
#include "builtin/object.hpp"
#include "builtin/string.hpp"

#ifdef RBX_WINDOWS
#include <malloc.h>
#endif

namespace rubinius {
  namespace pack18 {
    inline Object* to_int(STATE, CallFrame* call_frame, Object* obj) {
      Array* args = Array::create(state, 1);
      args->set(state, 0, obj);

      return G(rubinius)->send(state, call_frame, state->symbol("pack_to_int"), args);
    }

#define BITS_LONG   (RBX_SIZEOF_LONG * 8)

    inline long check_long(STATE, Integer* obj) {
      if((obj)->fixnum_p()) {
        return force_as<Fixnum>(obj)->to_long();
      } else {
        Bignum* big = as<Bignum>(obj);
        big->verify_size(state, BITS_LONG);
        return big->to_long();
      }
    }

#define BITS_64     (64)

    inline long long check_long_long(STATE, Integer* obj) {
      if((obj)->fixnum_p()) {
        return force_as<Fixnum>(obj)->to_long_long();
      } else {
        Bignum* big = as<Bignum>(obj);
        big->verify_size(state, BITS_64);
        return big->to_long_long();
      }
    }

    inline Object* to_f(STATE, CallFrame* call_frame, Object* obj) {
      Array* args = Array::create(state, 1);
      args->set(state, 0, obj);

      return G(rubinius)->send(state, call_frame, state->symbol("pack_to_float"), args);
    }

    inline String* encoding_string(STATE, CallFrame* call_frame, Object* obj,
                                          const char* coerce_name)
    {
      String* s = try_as<String>(obj);
      if(s) return s;

      Array* args = Array::create(state, 1);
      args->set(state, 0, obj);

      std::string coerce_method("pack_");
      coerce_method += coerce_name;
      Object* result = G(rubinius)->send(state, call_frame,
            state->symbol(coerce_method.c_str()), args);

      if(!result) return 0;
      return as<String>(result);
    }

    inline uint16_t swap_2bytes(uint16_t x) {
      return (((x & 0x00ff)<<8) | ((x & 0xff00)>>8));
    }

    inline uint32_t swap_4bytes(uint32_t x) {
      return (((x & 0x000000ff) << 24)
             |((x & 0xff000000) >> 24)
             |((x & 0x0000ff00) << 8)
             |((x & 0x00ff0000) >> 8));
    }

    inline uint64_t swap_8bytes(uint64_t x) {
      return (((x & 0x00000000000000ffLL) << 56)
             |((x & 0xff00000000000000LL) >> 56)
             |((x & 0x000000000000ff00LL) << 40)
             |((x & 0x00ff000000000000LL) >> 40)
             |((x & 0x0000000000ff0000LL) << 24)
             |((x & 0x0000ff0000000000LL) >> 24)
             |((x & 0x00000000ff000000LL) << 8)
             |((x & 0x000000ff00000000LL) >> 8));
    }

    inline void swap_float(std::string& str, float value) {
      uint32_t x;

      memcpy(&x, &value, sizeof(float));
      x = swap_4bytes(x);

      str.append((const char*)&x, sizeof(uint32_t));
    }

    inline void swap_double(std::string& str, double value) {
      uint64_t x;

      memcpy(&x, &value, sizeof(double));
      x = swap_8bytes(x);

      str.append((const char*)&x, sizeof(uint64_t));
    }

    inline void double_element(std::string& str, double value) {
      str.append((const char*)&value, sizeof(double));
    }

    inline void float_element(std::string& str, float value) {
      str.append((const char*)&value, sizeof(float));
    }

    inline void short_element(std::string& str, int16_t value) {
      str.append((const char*)&value, sizeof(int16_t));
    }

    inline void int_element(std::string& str, int32_t value) {
      str.append((const char*)&value, sizeof(int32_t));
    }

    inline void long_element(std::string& str, int64_t value) {
      str.append((const char*)&value, sizeof(int64_t));
    }

    inline int32_t int32_element(STATE, Integer* value) {
      if(value->fixnum_p()) {
        long l = as<Fixnum>(value)->to_long();
        if(l > INT32_MAX || l < INT32_MIN) {
          Exception::range_error(state, "Fixnum value out of range of int32");
        }
        return l;
      } else {
        Bignum* big = as<Bignum>(value);
        big->verify_size(state, 32);
        return big->to_int();
      }
    }

#define QUOTABLE_PRINTABLE_BUFSIZE 1024

    void quotable_printable(String* s, std::string& str, int count) {
      static char hex_table[] = "0123456789ABCDEF";
      char buf[QUOTABLE_PRINTABLE_BUFSIZE];

      uint8_t* b = s->byte_address();
      uint8_t* e = b + s->byte_size();
      int i = 0, n = 0, prev = -1;

      for(; b < e; b++) {
        if((*b > 126) || (*b < 32 && *b != '\n' && *b != '\t') || (*b == '=')) {
          buf[i++] = '=';
          buf[i++] = hex_table[*b >> 4];
          buf[i++] = hex_table[*b & 0x0f];
          n += 3;
          prev = -1;
        } else if(*b == '\n') {
          if(prev == ' ' || prev == '\t') {
            buf[i++] = '=';
            buf[i++] = *b;
          }
          buf[i++] = *b;
          n = 0;
          prev = *b;
        } else {
          buf[i++] = *b;
          n++;
          prev = *b;
        }

        if(n > count) {
          buf[i++] = '=';
          buf[i++] = '\n';
          n = 0;
          prev = '\n';
        }

        if(i > QUOTABLE_PRINTABLE_BUFSIZE - 5) {
          str.append(buf, i);
          i = 0;
        }
      }

      if(n > 0) {
        buf[i++] = '=';
        buf[i++] = '\n';
      }

      if(i > 0) {
        str.append(buf, i);
      }
    }

    static const char uu_table[] =
      "`!\"#$%&'()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\\]^_";
    static const char b64_table[] =
      "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";

#define b64_uu_byte1(t, b)      t[077 & (*b >> 2)]
#define b64_uu_byte2(t, b, c)   t[077 & (((*b << 4) & 060) | ((c >> 4) & 017))]
#define b64_uu_byte3(t, b, c)   t[077 & (((b[1] << 2) & 074) | ((c >> 6) & 03))];
#define b64_uu_byte4(t, b)      t[077 & b[2]];

    void b64_uu_encode(String* s, std::string& str, native_int count,
                              const char* table, int padding, bool encode_size)
    {
      char *buf = ALLOCA_N(char, count * 4 / 3 + 6);
      native_int i, chars, line, total = s->byte_size();
      uint8_t* b = s->byte_address();

      for(i = 0; total > 0; i = 0, total -= line) {
        line = total > count ? count : total;

        if(encode_size) buf[i++] = line + ' ';

        for(chars = line; chars >= 3; chars -= 3, b += 3) {
          buf[i++] = b64_uu_byte1(table, b);
          buf[i++] = b64_uu_byte2(table, b, b[1]);
          buf[i++] = b64_uu_byte3(table, b, b[2]);
          buf[i++] = b64_uu_byte4(table, b);
        }

        if(chars == 2) {
          buf[i++] = b64_uu_byte1(table, b);
          buf[i++] = b64_uu_byte2(table, b, b[1]);
          buf[i++] = b64_uu_byte3(table, b, '\0');
          buf[i++] = padding;
        } else if(chars == 1) {
          buf[i++] = b64_uu_byte1(table, b);
          buf[i++] = b64_uu_byte2(table, b, '\0');
          buf[i++] = padding;
          buf[i++] = padding;
        }

        b += chars;
        buf[i++] = '\n';
        str.append(buf, i);
      }
    }

    void utf8_encode(STATE, std::string& str, Integer* value) {
      int32_t v = int32_element(state, value);

      if(!(v & ~0x7f)) {
        str.push_back(v);
      } else if(!(v & ~0x7ff)) {
        str.push_back(((v >> 6) & 0xff) | 0xc0);
        str.push_back((v & 0x3f) | 0x80);
      } else if(!(v & ~0xffff)) {
        str.push_back(((v >> 12) & 0xff) | 0xe0);
        str.push_back(((v >> 6)  & 0x3f) | 0x80);
        str.push_back((v & 0x3f) | 0x80);
      } else if(!(v & ~0x1fffff)) {
        str.push_back(((v >> 18) & 0xff) | 0xf0);
        str.push_back(((v >> 12) & 0x3f) | 0x80);
        str.push_back(((v >> 6)  & 0x3f) | 0x80);
        str.push_back((v & 0x3f) | 0x80);
      } else if(!(v & ~0x3ffffff)) {
        str.push_back(((v >> 24) & 0xff) | 0xf8);
        str.push_back(((v >> 18) & 0x3f) | 0x80);
        str.push_back(((v >> 12) & 0x3f) | 0x80);
        str.push_back(((v >> 6)  & 0x3f) | 0x80);
        str.push_back((v & 0x3f) | 0x80);
      } else if(!(v & ~0x7fffffff)) {
        str.push_back(((v >> 30) & 0xff) | 0xfc);
        str.push_back(((v >> 24) & 0x3f) | 0x80);
        str.push_back(((v >> 18) & 0x3f) | 0x80);
        str.push_back(((v >> 12) & 0x3f) | 0x80);
        str.push_back(((v >> 6)  & 0x3f) | 0x80);
        str.push_back((v & 0x3f) | 0x80);
      } else {
        Exception::range_error(state, "pack('U') value out of range");
      }
    }

    void ber_encode(STATE, std::string& str, Integer* value) {
      if(!value->positive_p()) {
        Exception::argument_error(state, "cannot BER compress a negative number");
      }

      std::string buf;

      if(try_as<Bignum>(value)) {
        static Fixnum* base = Fixnum::from(128);
        while(try_as<Bignum>(value)) {
          Array* ary;
          if(value->fixnum_p()) {
            ary = as<Fixnum>(value)->divmod(state, base);
          } else {
            ary = as<Bignum>(value)->divmod(state, base);
          }
          buf.push_back(as<Fixnum>(ary->get(state, 1))->to_native() | 0x80);
          value = as<Integer>(ary->get(state, 0));
        }
      }

      long v = value->to_long();

      while(v) {
        buf.push_back((v & 0x7f) | 0x80);
        v >>= 7;
      }

      if(buf.size() > 0) {
        char* a = const_cast<char*>(buf.c_str());
        char* b = a + buf.size() - 1;

        // clear continue bit
        *a &= 0x7f;

        // reverse string
        while(a < b) {
          int k = *a;
          *a++ = *b;
          *b-- = k;
        }

        str.append(buf.c_str(), buf.size());
      } else {
        str.push_back(0);
      }
    }

    inline native_int bit_extra(String* s, bool rest, native_int& count) {
      native_int extra = 0;

      if(rest) {
        count = s->byte_size();
      } else {
        native_int size = s->byte_size();
        if(count > size) {
          extra = (count - size + 1) / 2;
          count = size;
        }
      }

      return extra;
    }

    void bit_high(String* s, std::string& str, native_int count) {
      uint8_t* b = s->byte_address();
      int byte = 0;

      for(native_int i = 0; i++ < count; b++) {
        byte |= *b & 1;
        if(i & 7) {
          byte <<= 1;
        } else {
          str.push_back(byte & 0xff);
          byte = 0;
        }
      }

      if (count & 7) {
        byte <<= 7 - (count & 7);
        str.push_back(byte & 0xff);
      }
    }

    void bit_low(String* s, std::string& str, native_int count) {
      uint8_t* b = s->byte_address();
      int byte = 0;

      for(native_int i = 0; i++ < count; b++) {
        if(*b & 1)
          byte |= 128;

        if(i & 7) {
          byte >>= 1;
        } else {
          str.push_back(byte & 0xff);
          byte = 0;
        }
      }

      if(count & 7) {
        byte >>= 7 - (count & 7);
        str.push_back(byte & 0xff);
      }
    }

    inline native_int hex_extra(String* s, bool rest, native_int& count) {
      native_int extra = 0;

      if(rest) {
        count = s->byte_size();
      } else {
        native_int size = s->byte_size();
        if(count > size) {
          extra = (count + 1) / 2 - (size + 1) / 2;
          count = size;
        }
      }

      return extra;
    }

    void hex_high(String* s, std::string& str, native_int count) {
      uint8_t* b = s->byte_address();
      int byte = 0;

      for(native_int i = 0; i++ < count; b++) {
        if(ISALPHA(*b)) {
          byte |= ((*b & 15) + 9) & 15;
        } else {
          byte |= *b & 15;
        }

        if(i & 1) {
          byte <<= 4;
        } else {
          str.push_back(byte & 0xff);
          byte = 0;
        }
      }

      if(count & 1) {
        str.push_back(byte & 0xff);
      }
    }

    void hex_low(String* s, std::string& str, native_int count) {
      uint8_t* b = s->byte_address();
      int byte = 0;

      for(native_int i = 0; i++ < count; b++) {
        if(ISALPHA(*b)) {
          byte |= (((*b & 15) + 9) & 15) << 4;
        } else {
          byte |= (*b & 15) << 4;
        }

        if(i & 1) {
          byte >>= 4;
        } else {
          str.push_back(byte & 0xff);
          byte = 0;
        }
      }

      if(count & 1) {
        str.push_back(byte & 0xff);
      }
    }

    ByteArray* prepare_directives(STATE, String* directives,
                                  const char** p, const char** pe)
    {
      native_int size = directives->byte_size();
      ByteArray* ba = ByteArray::create_pinned(state, size);
      char* b = reinterpret_cast<char*>(ba->raw_bytes());
      char* d = reinterpret_cast<char*>(directives->byte_address());
      int i = 0, j = 0;

      while(i < size) {
        switch(d[i]) {
        case 0:
        case ' ':
        case '\t':
        case '\n':
        case '\v':
        case '\f':
        case '\r':
          i++;
          break;
        case '#':
          while(++i < size && d[i] != '\n')
            ; // ignore
          if(d[i] == '\n') i++;
          break;
        default:
          b[j++] = d[i++];
          break;
        }
      }

      *p = const_cast<const char*>(b);
      *pe = *p + j;

      return ba;
    }

    void exceeds_length_of_string(STATE, native_int count) {
      std::ostringstream msg;
      msg << "X" << count << " exceeds length of string";
      Exception::argument_error(state, msg.str().c_str());
    }

    void non_native_error(STATE, const char c) {
      std::ostringstream msg;
      msg << "'" << c << "' allowed only after types sSiIlL";
      Exception::argument_error(state, msg.str().c_str());
    }
  }


// Pack Float elements
#define pack_float_elements(format)   pack_elements(Float, pack18::to_f, format)

#define pack_double_le                pack_float_elements(pack_double_element_le)
#define pack_double_be                pack_float_elements(pack_double_element_be)

#define pack_float_le                 pack_float_elements(pack_float_element_le)
#define pack_float_be                 pack_float_elements(pack_float_element_be)

// Pack Integer elements
#define pack_integer_elements(format) pack_elements(Integer, pack18::to_int, format)

#define pack_byte_element(v)          str.push_back(pack18::check_long(state, v))
#define pack_byte                     pack_integer_elements(pack_byte_element)

#define pack_short_le                 pack_integer_elements(pack_short_element_le)
#define pack_short_be                 pack_integer_elements(pack_short_element_be)

#define pack_int_le                   pack_integer_elements(pack_int_element_le)
#define pack_int_be                   pack_integer_elements(pack_int_element_be)

#define pack_long_le                  pack_integer_elements(pack_long_element_le)
#define pack_long_be                  pack_integer_elements(pack_long_element_be)

// Pack UTF-8 elements
#define pack_utf8_element(v)          pack18::utf8_encode(state, str, v)
#define pack_utf8                     pack_elements(Integer, pack18::to_int, pack_utf8_element)

// Pack BER-compressed integers
#define pack_ber_element(v)           pack18::ber_encode(state, str, v)
#define pack_ber                      pack_elements(Integer, pack18::to_int, pack_ber_element)

// Wraps the logic for iterating over a number of elements,
// coercing them to the correct class and formatting them
// for the output string.
#define pack_elements(T, coerce, format)        \
  for(; index < stop; index++) {                \
    Object* item = self->get(state, index);     \
    T* value = try_as<T>(item);                 \
    if(!value) {                                \
      item = coerce(state, call_frame, item);   \
      if(!item) return 0;                       \
      value = as<T>(item);                      \
    }                                           \
    format(value);                              \
  }

// Macros that depend on endianness
#ifdef RBX_LITTLE_ENDIAN

# define pack_double_element_le(v)  (pack18::double_element(str, (v)->val))
# define pack_double_element_be(v)  (pack18::swap_double(str, (v)->val))
# define pack_double                pack_double_le

# define pack_float_element_le(v)   (pack18::float_element(str, (v)->val))
# define pack_float_element_be(v)   (pack18::swap_float(str, (v)->val))
# define pack_float                 pack_float_le

# define pack_short_element_le(v)   (pack18::short_element(str, pack18::check_long(state, v)))
# define pack_short_element_be(v)   (pack18::short_element(str, \
                                        pack18::swap_2bytes(pack18::check_long(state, v))))
# define pack_short                 pack_short_le

# define pack_int_element_le(v)     (pack18::int_element(str, pack18::check_long(state, v)))
# define pack_int_element_be(v)     (pack18::int_element(str, \
                                        pack18::swap_4bytes(pack18::check_long(state, v))))
# define pack_int                   pack_int_le

# define pack_long_element_le(v)    (pack18::long_element(str, pack18::check_long_long(state, v)))
# define pack_long_element_be(v)    (pack18::long_element(str, \
                                        pack18::swap_8bytes(pack18::check_long_long(state, v))))
# define pack_long                  pack_long_le

#else // Big endian

# define pack_double_element_le(v)  (pack18::swap_double(str, (v)->val))
# define pack_double_element_be(v)  (pack18::double_element(str, (v)->val))
# define pack_double                pack_double_be

# define pack_float_element_le(v)   (pack18::swap_float(str, (v)->val))
# define pack_float_element_be(v)   (pack18::float_element(str, (v)->val))
# define pack_float                 pack_float_be

# define pack_short_element_le(v)   (pack18::short_element(str, \
                                        pack18::swap_2bytes(pack18::check_long(state, v))))
# define pack_short_element_be(v)   (pack18::short_element(str, pack18::check_long(state, v)))
# define pack_short                 pack_short_be

# define pack_int_element_le(v)     (pack18::int_element(str, \
                                        pack18::swap_4bytes(pack18::check_long(state, v))))
# define pack_int_element_be(v)     (pack18::int_element(str, pack18::check_long(state, v)))
# define pack_int                   pack_int_be

# define pack_long_element_le(v)    (pack18::long_element(str, \
                                        pack18::swap_8bytes(pack18::check_long_long(state, v))))
# define pack_long_element_be(v)    (pack18::long_element(str, pack18::check_long_long(state, v)))
# define pack_long                  pack_long_be

#endif

  String* Array::pack18(STATE, String* directives, CallFrame* call_frame) {
    // Ragel-specific variables
    const char* p;
    const char* pe;
    ByteArray* d = pack18::prepare_directives(state, directives, &p, &pe);
    const char *eof = pe;
    int cs;

    // pack-specific variables
    Array* self = this;
    OnStack<2> sv(state, self, d);

    native_int array_size = self->size();
    native_int index = 0;
    native_int count = 0;
    native_int stop = 0;
    bool rest = false;
    bool platform = false;
    bool tainted = false;

    String* string_value = 0;
    std::string str("");

    // Use information we have to reduce repeated allocation.
    str.reserve(array_size * 4);

    if(CBOOL(directives->tainted_p(state))) tainted = true;
%%{

  machine pack;

  include "pack.rl";

}%%

    if(en_main) {
      // do nothing
    }

    return force_as<String>(Primitives::failure());
  }
}
