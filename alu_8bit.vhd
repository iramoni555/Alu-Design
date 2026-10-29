----------------------------------------------------------------------------------
-- Title       : 8-bit Arithmetic Logic Unit (ALU)
-- File        : alu_8bit.vhd
-- Target      : Xilinx ISE 14.x, Spartan-6 (xc6slx4-3-tqg144), XST / ISim
-- Language    : VHDL-93 (purely combinational design)
--
-- Operation select (SEL):
--   0000 ADD   RESULT = A + B            0001 SUB   RESULT = A - B
--   0010 AND   RESULT = A and B          0011 OR    RESULT = A or B
--   0100 XOR   RESULT = A xor B          0101 NOT   RESULT = not A
--   0110 NAND  RESULT = A nand B         0111 NOR   RESULT = A nor B
--   1000 XNOR  RESULT = A xnor B         1001 INC   RESULT = A + 1
--   1010 DEC   RESULT = A - 1            1011 SHL   RESULT = A << 1 (logical)
--   1100 SHR   RESULT = A >> 1 (logical) 1101 ROL   RESULT = rotate A left
--   1110 ROR   RESULT = rotate A right   1111 PASS  RESULT = B
--
-- Flags:
--   CARRY : ADD/INC -> carry out of bit 7
--           SUB/DEC -> borrow (1 when A < B, or A = 0 for DEC)
--           SHL/ROL -> old A(7);  SHR/ROR -> old A(0);  logic ops -> 0
--   ZERO  : 1 when RESULT = 0
--   NEG   : copy of RESULT(7) (sign bit, two's complement)
--   OVF   : signed (two's complement) overflow for ADD, SUB, INC, DEC; else 0
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity alu_8bit is
    Port ( A      : in  STD_LOGIC_VECTOR (7 downto 0);
           B      : in  STD_LOGIC_VECTOR (7 downto 0);
           SEL    : in  STD_LOGIC_VECTOR (3 downto 0);
           RESULT : out STD_LOGIC_VECTOR (7 downto 0);
           CARRY  : out STD_LOGIC;
           ZERO   : out STD_LOGIC;
           NEG    : out STD_LOGIC;
           OVF    : out STD_LOGIC);
end alu_8bit;

architecture Behavioral of alu_8bit is
begin

    alu_proc : process (A, B, SEL)
        variable ua : unsigned(7 downto 0);
        variable ub : unsigned(7 downto 0);
        variable r  : unsigned(8 downto 0);   -- bit 8 holds carry / borrow
        variable c  : STD_LOGIC;
        variable v  : STD_LOGIC;
    begin
        ua := unsigned(A);
        ub := unsigned(B);
        r  := (others => '0');
        c  := '0';
        v  := '0';

        case SEL is
            when "0000" =>                                   -- ADD
                r := ('0' & ua) + ('0' & ub);
                c := r(8);
                v := (not (A(7) xor B(7))) and (A(7) xor r(7));

            when "0001" =>                                   -- SUB
                r := ('0' & ua) - ('0' & ub);
                c := r(8);                                   -- borrow
                v := (A(7) xor B(7)) and (A(7) xor r(7));

            when "0010" =>  r(7 downto 0) := ua and ub;      -- AND
            when "0011" =>  r(7 downto 0) := ua or  ub;      -- OR
            when "0100" =>  r(7 downto 0) := ua xor ub;      -- XOR
            when "0101" =>  r(7 downto 0) := not ua;         -- NOT A
            when "0110" =>  r(7 downto 0) := ua nand ub;     -- NAND
            when "0111" =>  r(7 downto 0) := ua nor  ub;     -- NOR
            when "1000" =>  r(7 downto 0) := ua xnor ub;     -- XNOR

            when "1001" =>                                   -- INC
                r := ('0' & ua) + 1;
                c := r(8);
                if ua = 127 then v := '1'; end if;           -- 0x7F -> 0x80

            when "1010" =>                                   -- DEC
                r := ('0' & ua) - 1;
                c := r(8);                                   -- borrow when A = 0
                if ua = 128 then v := '1'; end if;           -- 0x80 -> 0x7F

            when "1011" =>                                   -- SHL
                r(7 downto 0) := ua(6 downto 0) & '0';
                c := ua(7);

            when "1100" =>                                   -- SHR
                r(7 downto 0) := '0' & ua(7 downto 1);
                c := ua(0);

            when "1101" =>                                   -- ROL
                r(7 downto 0) := ua(6 downto 0) & ua(7);
                c := ua(7);

            when "1110" =>                                   -- ROR
                r(7 downto 0) := ua(0) & ua(7 downto 1);
                c := ua(0);

            when "1111" =>  r(7 downto 0) := ub;             -- PASS B

            when others =>  r := (others => '0');            -- undefined SEL
        end case;

        RESULT <= STD_LOGIC_VECTOR(r(7 downto 0));
        CARRY  <= c;
        OVF    <= v;
        NEG    <= r(7);
        if r(7 downto 0) = "00000000" then
            ZERO <= '1';
        else
            ZERO <= '0';
        end if;
    end process alu_proc;

end Behavioral;
