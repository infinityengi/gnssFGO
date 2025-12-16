# Quick Reference: SBF Block Byte Layouts

**For use during implementation - print this page!**

---

## GPSNav (Block 5891) - 140 bytes

```
┌─────────────────────────────────────────────────────────────┐
│ SBF Header (8 bytes)                                        │
│ Sync: 0x24 0x40 | CRC(2) | ID:5891(2) | Length(2)         │
├─────────────────────────────────────────────────────────────┤
│ Timestamp (6 bytes)                                         │
│ TOW(4) | WNc(2)                                             │
├─────────────────────────────────────────────────────────────┤
│ Satellite Info (4 bytes)                                    │
│ PRN(1) | Reserved(1) | WN(2)                               │
├─────────────────────────────────────────────────────────────┤
│ L2 & Health (7 bytes)                                       │
│ CAorPonL2(1) | URA(1) | health(1) | L2DataFlag(1) |        │
│ IODC(2) | IODE2(1) | IODE3(1) | FitIntFlg(1) | Res2(1)    │
├─────────────────────────────────────────────────────────────┤
│ Clock (12 bytes)                                            │
│ T_gd(4) | t_oc(4) | a_f2(4) | a_f1(4) | a_f0(4)           │
├─────────────────────────────────────────────────────────────┤
│ Orbital Elements (56 bytes) - 14 parameters                 │
│ C_rs(4) | DEL_N(4) | M_0(8) | C_uc(4) | e(8) | C_us(4) |   │
│ SQRT_A(8) | t_oe(4) | C_ic(4) | OMEGA_0(8) | C_is(4) |     │
│ L_0(8) | C_rc(4) | omega(8) | OMEGADOT(4) | IDOT(4)        │
├─────────────────────────────────────────────────────────────┤
│ Week Numbers (4 bytes)                                      │
│ WNt_oc(2) | WNt_oe(2)                                       │
├─────────────────────────────────────────────────────────────┤
│ Padding (variable)                                          │
└─────────────────────────────────────────────────────────────┘

Key Offsets:
  0-7:    Header
  8-13:   Timestamp (TOW=8-11, WNc=12-13)
  14:     PRN ◄── Start of payload
  42-49:  M_0 (double, f8)
  62-69:  SQRT_A (double, f8)
```

---

## GALNav (Block 4002) - 160+ bytes

```
┌─────────────────────────────────────────────────────────────┐
│ SBF Header (8 bytes)                                        │
│ Sync: 0x24 0x40 | CRC(2) | ID:4002(2) | Length(2)         │
├─────────────────────────────────────────────────────────────┤
│ Timestamp (6 bytes)                                         │
│ TOW(4) | WNc(2)                                             │
├─────────────────────────────────────────────────────────────┤
│ Satellite & Source (2 bytes)                                │
│ SVID(1) | Source(1): 2=I/NAV, 16=F/NAV                     │
├─────────────────────────────────────────────────────────────┤
│ Orbital Elements (56 bytes) - 14 parameters                 │
│ SQRT_A(8) | M_0(8) | e(8) | i_0(8) | omega(8) | OMEGA_0(8)│
│ OMEGADOT(4) | IDOT(4) | DEL_N(4) | C_uc(4) | C_us(4) |     │
│ C_rc(4) | C_ic(4) | C_is(4) | t_oe(4)                      │
├─────────────────────────────────────────────────────────────┤
│ Clock (24 bytes)                                            │
│ t_oc(4) | a_f2(4) | a_f1(4) | a_f0(8) | WNt_oe(2) |        │
│ WNt_oc(2) | IODnav(2)                                       │
├─────────────────────────────────────────────────────────────┤
│ Health & Accuracy (10 bytes)                                │
│ Health_OSSOL(2) | Health_PRS(1) | SISA_L1E5a(1) |          │
│ SISA_L1E5b(1) | SISA_L1A E6A(1) | BGD_L1E5a(4) |           │
│ BGD_L1E5b(4) | BGD_L1AE6A(4) | CNAVenc(1)                  │
├─────────────────────────────────────────────────────────────┤
│ Padding (variable)                                          │
└─────────────────────────────────────────────────────────────┘

Key Offsets:
  0-7:    Header
  8-13:   Timestamp
  14:     SVID ◄── Start of payload
  15:     Source (I/NAV=2, F/NAV=16)
  
Note: Two blocks per satellite if receiving both I/NAV & F/NAV
```

---

## GPSIon (Block 5893) - 48 bytes

```
┌─────────────────────────────────────────────────────────────┐
│ SBF Header (8 bytes)                                        │
│ Sync: 0x24 0x40 | CRC(2) | ID:5893(2) | Length(2)         │
├─────────────────────────────────────────────────────────────┤
│ Timestamp (6 bytes)                                         │
│ TOW(4) | WNc(2)                                             │
├─────────────────────────────────────────────────────────────┤
│ Satellite (2 bytes)                                         │
│ PRN(1) | Reserved(1)                                        │
├─────────────────────────────────────────────────────────────┤
│ Klobuchar Coefficients (32 bytes)                           │
│ alpha_0(4) | alpha_1(4) | alpha_2(4) | alpha_3(4) |        │
│ beta_0(4) | beta_1(4) | beta_2(4) | beta_3(4)              │
├─────────────────────────────────────────────────────────────┤
│ Padding (variable)                                          │
└─────────────────────────────────────────────────────────────┘

Key Offsets:
  0-7:     Header
  8-13:    Timestamp
  14:      PRN
  20-51:   8 Klobuchar coefficients (4 bytes each, f4)

Units:
  alpha_i: seconds / semi-circle^i
  beta_i:  seconds / semi-circle^i
```

---

## GALIon (Block 4030) - 36 bytes

```
┌─────────────────────────────────────────────────────────────┐
│ SBF Header (8 bytes)                                        │
│ Sync: 0x24 0x40 | CRC(2) | ID:4030(2) | Length(2)         │
├─────────────────────────────────────────────────────────────┤
│ Timestamp (6 bytes)                                         │
│ TOW(4) | WNc(2)                                             │
├─────────────────────────────────────────────────────────────┤
│ Satellite & Source (2 bytes)                                │
│ SVID(1) | Source(1): 2=I/NAV, 16=F/NAV                     │
├─────────────────────────────────────────────────────────────┤
│ Ionosphere (12 bytes)                                       │
│ a_i0(4) | a_i1(4) | a_i2(4)                                │
├─────────────────────────────────────────────────────────────┤
│ Storm Flags (1 byte)                                        │
│ SF1(bit0) | SF2(bit1) | SF3(bit2) | SF4(bit3) | SF5(bit4)  │
├─────────────────────────────────────────────────────────────┤
│ Padding (variable)                                          │
└─────────────────────────────────────────────────────────────┘

Key Offsets:
  0-7:     Header
  8-13:    Timestamp
  14:      SVID
  15:      Source
  20-31:   3 ionosphere coefficients (4 bytes each, f4)
  32:      Storm flags

Units:
  a_i: 1e-22 W/(m²Hz) raised to appropriate power
```

---

## GALGstGps (Block 4032) - 32 bytes

```
┌─────────────────────────────────────────────────────────────┐
│ SBF Header (8 bytes)                                        │
│ Sync: 0x24 0x40 | CRC(2) | ID:4032(2) | Length(2)         │
├─────────────────────────────────────────────────────────────┤
│ Timestamp (6 bytes)                                         │
│ TOW(4) | WNc(2)                                             │
├─────────────────────────────────────────────────────────────┤
│ Satellite & Source (2 bytes)                                │
│ SVID(1) | Source(1): 2=I/NAV, 16=F/NAV                     │
├─────────────────────────────────────────────────────────────┤
│ Time Offset (8 bytes)                                       │
│ A_0G(4) | A_1G(4)                                           │
├─────────────────────────────────────────────────────────────┤
│ Reference Time (4 bytes)                                    │
│ t_oG(4)                                                      │
├─────────────────────────────────────────────────────────────┤
│ Week Number (1 byte)                                        │
│ WN_oG(1): 6-bit week number                                 │
├─────────────────────────────────────────────────────────────┤
│ Padding (variable)                                          │
└─────────────────────────────────────────────────────────────┘

Key Offsets:
  0-7:     Header
  8-13:    Timestamp
  14:      SVID
  15:      Source
  20-23:   A_0G (f4)
  24-27:   A_1G (f4)
  28-31:   t_oG (u4)
  32:      WN_oG (u1, use 6 bits)

Units:
  A_0G: 1e9 nanoseconds (ns)
  A_1G: 1e9 ns/s
```

---

## Parsing Template (C++)

```cpp
// Generic structure for all SBF blocks
struct SBF_Block {
    // Header (always present)
    uint8_t sync1;      // Offset 0, should be 0x24
    uint8_t sync2;      // Offset 1, should be 0x40
    uint16_t crc;       // Offset 2-3 (little-endian)
    uint16_t id;        // Offset 4-5 (little-endian)
    uint16_t length;    // Offset 6-7 (little-endian)
    
    // Timestamp (always present after header)
    uint32_t tow;       // Offset 8-11 (little-endian, units: 0.001s)
    uint16_t wnc;       // Offset 12-13 (little-endian, units: 1 week)
    
    // Block-specific data starts at offset 14
    // ...
};

// Parse helper
template<typename T>
T extract_little_endian(const uint8_t* buffer, int offset) {
    T value;
    std::memcpy(&value, buffer + offset, sizeof(T));
    return value;
}

// Usage example
uint32_t tow = extract_little_endian<uint32_t>(buffer, 8);
uint16_t wnc = extract_little_endian<uint16_t>(buffer, 12);
double m0 = extract_little_endian<double>(buffer, 42);  // In GPSNav
```

---

## Block IDs at a Glance

| Block Name | Decimal | Hex | Message Type | Update Rate |
|-----------|---------|-----|--------------|------------|
| GPSNav | 5891 | 0x1703 | GPSEPHEM | OnChange (~2 hrs) |
| GALNav | 4002 | 0x0FA2 | GALFNAVEPHEMERIS | OnChange (~10 sec) |
| GPSIon | 5893 | 0x1705 | IONUTC | OnChange (~3-4 hrs) |
| GALIon | 4030 | 0x0FAE | GALIon | OnChange (variable) |
| GALGstGps | 4032 | 0x0FB0 | GALCLOCK | OnChange (several/hr) |

---

## Validation Checklist

### Immediately After Parsing

```cpp
// GPSNav validation
assert(gps_nav.prn >= 1 && gps_nav.prn <= 32);        // Valid PRN
assert(gps_nav.sqrt_a > 26000000.0);                  // ~26M meters for GPS
assert(gps_nav.e >= 0.0 && gps_nav.e < 0.1);         // Typical eccentricity
assert(gps_nav.iodc != 0 || gps_nav.iode2 != 0);     // At least one non-zero

// GALNav validation
assert(gal_nav.svid >= 1 && gal_nav.svid <= 36);     // Valid Galileo SV
assert(gal_nav.source == 2 || gal_nav.source == 16); // I/NAV or F/NAV
assert(gal_nav.iod_nav >= 0 && gal_nav.iod_nav < 1024); // 10-bit field

// GPSIon validation
assert(gps_ion.alpha_0 != 0.0 || gps_ion.alpha_1 != 0.0); // At least something
assert(gps_ion.beta_0 > 0.0);                         // Positive model period

// GALIon validation
assert(gal_ion.a_i0 >= 0.0);                          // Ionization level
assert(gal_ion.storm_flags >= 0 && gal_ion.storm_flags < 32); // 5-bit field

// GALGstGps validation
assert(gal_ggto.a0g != 0.0 || gal_ggto.a1g != 0.0);  // Some offset
assert(gal_ggto.t0g < 604800);                        // Within one week
```

---

## Header Diagram

```
┌──────────┬──────────┬──────┬──────┬──────┐
│ Sync1    │ Sync2    │ CRC  │ ID   │ Len  │
│ 0x24     │ 0x40     │ (2)  │ (2)  │ (2)  │
├──────────┼──────────┼──────┼──────┼──────┤
│ Byte 0   │ Byte 1   │ 2-3  │ 4-5  │ 6-7  │
│ '$'      │ '@'      │      │      │      │
└──────────┴──────────┴──────┴──────┴──────┘

┌─────────────┬─────────┐
│ TOW (ms)    │ WNc     │
│ (4 bytes)   │ (2)     │
├─────────────┼─────────┤
│ Bytes 8-11  │ 12-13   │
│ u32         │ u16     │
└─────────────┴─────────┘

Payload starts at byte 14
```

---

## Data Type Reference

```
u1 = uint8_t      (1 byte)
u2 = uint16_t     (2 bytes, little-endian)
u4 = uint32_t     (4 bytes, little-endian)
f4 = float        (4 bytes, IEEE 754, little-endian)
f8 = double       (8 bytes, IEEE 754, little-endian)

Always use std::memcpy or bit_cast for safe access!
```

---

**Print this page and keep it handy during implementation!**

