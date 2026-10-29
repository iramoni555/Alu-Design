----------------------------------------------------------------------------------
-- Title       : Self-checking testbench for alu_8bit
-- File        : alu_8bit_tb.vhd
-- Target      : Xilinx ISE 14.x ISim (also runs on GHDL, VHDL-93)
--
-- Stage 1 : directed tests (expected values worked out by hand)
-- Stage 2 : corner-value sweep  (7 x 7 operand pairs x 16 opcodes)
-- Stage 3 : pseudo-random sweep (LFSR generated operands x 16 opcodes)
-- Stages 2 and 3 compare against an independent integer-arithmetic model.
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity alu_8bit_tb is
end alu_8bit_tb;

architecture Behavioral of alu_8bit_tb is

    component alu_8bit
        Port ( A      : in  STD_LOGIC_VECTOR (7 downto 0);
               B      : in  STD_LOGIC_VECTOR (7 downto 0);
               SEL    : in  STD_LOGIC_VECTOR (3 downto 0);
               RESULT : out STD_LOGIC_VECTOR (7 downto 0);
               CARRY  : out STD_LOGIC;
               ZERO   : out STD_LOGIC;
               NEG    : out STD_LOGIC;
               OVF    : out STD_LOGIC);
    end component;

    signal A_tb, B_tb       : STD_LOGIC_VECTOR (7 downto 0) := (others => '0');
    signal SEL_tb           : STD_LOGIC_VECTOR (3 downto 0) := (others => '0');
    signal RESULT_tb        : STD_LOGIC_VECTOR (7 downto 0);
    signal CARRY_tb, ZERO_tb, NEG_tb, OVF_tb : STD_LOGIC;

    constant T : time := 10 ns;

    -- opcodes
    constant OP_ADD  : STD_LOGIC_VECTOR(3 downto 0) := "0000";
    constant OP_SUB  : STD_LOGIC_VECTOR(3 downto 0) := "0001";
    constant OP_AND  : STD_LOGIC_VECTOR(3 downto 0) := "0010";
    constant OP_OR   : STD_LOGIC_VECTOR(3 downto 0) := "0011";
    constant OP_XOR  : STD_LOGIC_VECTOR(3 downto 0) := "0100";
    constant OP_NOT  : STD_LOGIC_VECTOR(3 downto 0) := "0101";
    constant OP_NAND : STD_LOGIC_VECTOR(3 downto 0) := "0110";
    constant OP_NOR  : STD_LOGIC_VECTOR(3 downto 0) := "0111";
    constant OP_XNOR : STD_LOGIC_VECTOR(3 downto 0) := "1000";
    constant OP_INC  : STD_LOGIC_VECTOR(3 downto 0) := "1001";
    constant OP_DEC  : STD_LOGIC_VECTOR(3 downto 0) := "1010";
    constant OP_SHL  : STD_LOGIC_VECTOR(3 downto 0) := "1011";
    constant OP_SHR  : STD_LOGIC_VECTOR(3 downto 0) := "1100";
    constant OP_ROL  : STD_LOGIC_VECTOR(3 downto 0) := "1101";
    constant OP_ROR  : STD_LOGIC_VECTOR(3 downto 0) := "1110";
    constant OP_PASS : STD_LOGIC_VECTOR(3 downto 0) := "1111";

begin

    UUT : alu_8bit port map ( A => A_tb, B => B_tb, SEL => SEL_tb,
                              RESULT => RESULT_tb, CARRY => CARRY_tb,
                              ZERO => ZERO_tb, NEG => NEG_tb, OVF => OVF_tb );

    stim_proc : process

        variable errors : integer := 0;
        variable tests  : integer := 0;

        -- convert 0..255 to its signed (two's complement) value
        function to_s (x : integer) return integer is
        begin
            if x >= 128 then return x - 256; else return x; end if;
        end function;

        function b2s (f : boolean) return STD_LOGIC is
        begin
            if f then return '1'; else return '0'; end if;
        end function;

        -- apply stimulus, wait, compare against expected
        procedure check (a, b : in integer;
                         sel  : in STD_LOGIC_VECTOR(3 downto 0);
                         e_res : in integer;
                         e_c, e_z, e_n, e_v : in STD_LOGIC;
                         tag : in string) is
        begin
            A_tb   <= STD_LOGIC_VECTOR(to_unsigned(a, 8));
            B_tb   <= STD_LOGIC_VECTOR(to_unsigned(b, 8));
            SEL_tb <= sel;
            wait for T;
            tests := tests + 1;
            if RESULT_tb /= STD_LOGIC_VECTOR(to_unsigned(e_res, 8)) or
               CARRY_tb /= e_c or ZERO_tb /= e_z or
               NEG_tb   /= e_n or OVF_tb  /= e_v then
                errors := errors + 1;
                report "FAIL [" & tag & "] A=" & integer'image(a) &
                       " B=" & integer'image(b) &
                       " expected RES=" & integer'image(e_res) &
                       " got RES=" & integer'image(to_integer(unsigned(RESULT_tb))) &
                       " (C Z N V = " & STD_LOGIC'image(CARRY_tb) &
                       STD_LOGIC'image(ZERO_tb) & STD_LOGIC'image(NEG_tb) &
                       STD_LOGIC'image(OVF_tb) & ")"
                       severity error;
            end if;
        end procedure;

        -- independent reference model (integer arithmetic) + compare
        procedure check_model (a, b : in integer;
                               sel  : in STD_LOGIC_VECTOR(3 downto 0);
                               tag  : in string) is
            variable r          : integer;
            variable c, v       : boolean;
            variable ua, ub, ur : unsigned(7 downto 0);
        begin
            c := false; v := false;
            ua := to_unsigned(a, 8);
            ub := to_unsigned(b, 8);
            ur := (others => '0');
            r  := 0;
            if    sel = OP_ADD then
                r := a + b;
                c := (r >= 256);
                v := ((to_s(a) + to_s(b)) > 127) or ((to_s(a) + to_s(b)) < -128);
                r := r mod 256;
            elsif sel = OP_SUB then
                r := a - b;
                c := (a < b);
                v := ((to_s(a) - to_s(b)) > 127) or ((to_s(a) - to_s(b)) < -128);
                r := (r + 256) mod 256;
            elsif sel = OP_AND  then ur := ua and ub;   r := to_integer(ur);
            elsif sel = OP_OR   then ur := ua or ub;    r := to_integer(ur);
            elsif sel = OP_XOR  then ur := ua xor ub;   r := to_integer(ur);
            elsif sel = OP_NOT  then ur := not ua;      r := to_integer(ur);
            elsif sel = OP_NAND then ur := ua nand ub;  r := to_integer(ur);
            elsif sel = OP_NOR  then ur := ua nor ub;   r := to_integer(ur);
            elsif sel = OP_XNOR then ur := ua xnor ub;  r := to_integer(ur);
            elsif sel = OP_INC  then
                c := (a = 255);
                v := (to_s(a) + 1 > 127);
                r := (a + 1) mod 256;
            elsif sel = OP_DEC  then
                c := (a = 0);
                v := (to_s(a) - 1 < -128);
                r := (a + 255) mod 256;
            elsif sel = OP_SHL  then c := (a >= 128);       r := (a * 2) mod 256;
            elsif sel = OP_SHR  then c := ((a mod 2) = 1);  r := a / 2;
            elsif sel = OP_ROL  then c := (a >= 128);       r := ((a * 2) mod 256) + (a / 128);
            elsif sel = OP_ROR  then c := ((a mod 2) = 1);  r := (a / 2) + (a mod 2) * 128;
            else                     r := b;                -- PASS B
            end if;
            check(a, b, sel, r, b2s(c), b2s(r = 0), b2s(r >= 128), b2s(v), tag);
        end procedure;

        -- 16-bit LFSR (x^16 + x^14 + x^13 + x^11 + 1), deterministic
        variable lfsr : unsigned(15 downto 0) := x"ACE1";
        variable fb   : STD_LOGIC;
        variable ra, rb : integer;

        type int_arr is array (0 to 6) of integer;
        constant CORNER : int_arr := (0, 1, 127, 128, 255, 85, 170);

    begin
        wait for 20 ns;

        ------------------------------------------------------------------
        -- STAGE 1 : directed tests          check(A,B,SEL,RES,C,Z,N,V,tag)
        ------------------------------------------------------------------
        -- ADD
        check(16#25#, 16#1A#, OP_ADD, 16#3F#, '0','0','0','0', "ADD 25+1A");
        check(16#FF#, 16#01#, OP_ADD, 16#00#, '1','1','0','0', "ADD FF+01 carry");
        check(16#7F#, 16#01#, OP_ADD, 16#80#, '0','0','1','1', "ADD 7F+01 ovf");
        check(16#80#, 16#80#, OP_ADD, 16#00#, '1','1','0','1', "ADD 80+80 ovf+carry");
        -- SUB
        check(16#30#, 16#10#, OP_SUB, 16#20#, '0','0','0','0', "SUB 30-10");
        check(16#10#, 16#30#, OP_SUB, 16#E0#, '1','0','1','0', "SUB 10-30 borrow");
        check(16#55#, 16#55#, OP_SUB, 16#00#, '0','1','0','0', "SUB 55-55 zero");
        check(16#80#, 16#01#, OP_SUB, 16#7F#, '0','0','0','1', "SUB 80-01 ovf");
        check(16#7F#, 16#FF#, OP_SUB, 16#80#, '1','0','1','1', "SUB 7F-FF ovf");
        -- Logic
        check(16#F0#, 16#3C#, OP_AND,  16#30#, '0','0','0','0', "AND");
        check(16#F0#, 16#0F#, OP_OR,   16#FF#, '0','0','1','0', "OR");
        check(16#AA#, 16#FF#, OP_XOR,  16#55#, '0','0','0','0', "XOR");
        check(16#AA#, 16#AA#, OP_XOR,  16#00#, '0','1','0','0', "XOR zero");
        check(16#0F#, 16#00#, OP_NOT,  16#F0#, '0','0','1','0', "NOT");
        check(16#F0#, 16#3C#, OP_NAND, 16#CF#, '0','0','1','0', "NAND");
        check(16#F0#, 16#0F#, OP_NOR,  16#00#, '0','1','0','0', "NOR");
        check(16#AA#, 16#AA#, OP_XNOR, 16#FF#, '0','0','1','0', "XNOR");
        -- INC / DEC
        check(16#FF#, 16#00#, OP_INC, 16#00#, '1','1','0','0', "INC FF wrap");
        check(16#7F#, 16#00#, OP_INC, 16#80#, '0','0','1','1', "INC 7F ovf");
        check(16#00#, 16#00#, OP_DEC, 16#FF#, '1','0','1','0', "DEC 00 borrow");
        check(16#80#, 16#00#, OP_DEC, 16#7F#, '0','0','0','1', "DEC 80 ovf");
        -- Shift / rotate (A = 0x81)
        check(16#81#, 16#00#, OP_SHL, 16#02#, '1','0','0','0', "SHL 81");
        check(16#81#, 16#00#, OP_SHR, 16#40#, '1','0','0','0', "SHR 81");
        check(16#81#, 16#00#, OP_ROL, 16#03#, '1','0','0','0', "ROL 81");
        check(16#81#, 16#00#, OP_ROR, 16#C0#, '1','0','1','0', "ROR 81");
        -- Pass B
        check(16#00#, 16#A5#, OP_PASS, 16#A5#, '0','0','1','0', "PASS B");

        ------------------------------------------------------------------
        -- STAGE 2 : corner-value sweep against the reference model
        ------------------------------------------------------------------
        for op in 0 to 15 loop
            for i in 0 to 6 loop
                for j in 0 to 6 loop
                    check_model(CORNER(i), CORNER(j),
                                STD_LOGIC_VECTOR(to_unsigned(op, 4)), "corner");
                end loop;
            end loop;
        end loop;

        ------------------------------------------------------------------
        -- STAGE 3 : pseudo-random sweep against the reference model
        ------------------------------------------------------------------
        for n in 1 to 200 loop
            for k in 0 to 15 loop
                fb   := lfsr(15) xor lfsr(13) xor lfsr(12) xor lfsr(10);
                lfsr := lfsr(14 downto 0) & fb;
                ra   := to_integer(lfsr(7 downto 0));
                fb   := lfsr(15) xor lfsr(13) xor lfsr(12) xor lfsr(10);
                lfsr := lfsr(14 downto 0) & fb;
                rb   := to_integer(lfsr(7 downto 0));
                check_model(ra, rb, STD_LOGIC_VECTOR(to_unsigned(k, 4)), "random");
            end loop;
        end loop;

        ------------------------------------------------------------------
        -- Summary
        ------------------------------------------------------------------
        if errors = 0 then
            report "PASS: alu_8bit testbench completed - " &
                   integer'image(tests) & " checks, 0 errors" severity note;
        else
            report "FAIL: alu_8bit testbench - " & integer'image(errors) &
                   " errors out of " & integer'image(tests) & " checks"
                   severity error;
        end if;
        wait;
    end process stim_proc;

end Behavioral;
