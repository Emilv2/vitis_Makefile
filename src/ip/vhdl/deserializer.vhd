
----------------------------------------------------------------------------------
-- Company:
-- Engineer:
--
-- Create Date:    23:28:20 03/05/2020
-- Design Name:
-- Module Name:    ro2 - Behavioral
-- Project Name:
-- Target Devices:
-- Tool versions:
-- Description:
--
-- Dependencies:
--
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
--
----------------------------------------------------------------------------------

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

entity deserializer is
  generic (
    DATA_WIDTH : integer := 32
  );
  port (
    clk_i    : in    std_logic;
    bit_i    : in    std_logic;
    enable_i : in    std_logic;
    n_rst_i  : in    std_logic;
    data_o   : out   std_logic_vector(DATA_WIDTH -1  downto 0);
    valid_o  : out   std_logic
  );
end entity deserializer;

architecture rtl of deserializer is

  type t_state is (
    IDLE,
    RUNNING
  );

  signal s_state : t_state;
  signal s_data  : std_logic_vector(DATA_WIDTH -1 downto 0);
  signal s_valid : std_logic;

  --signal v_count : integer range 0 to DATA_WIDTH - 1;

begin

  data_o  <= s_data;
  valid_o <= s_valid;

  state_machine : process (clk_i) is

    variable v_count  : integer range 0 to DATA_WIDTH - 1;
    variable v_buffer : std_logic_vector(DATA_WIDTH -1 downto 0);

  begin

    if (rising_edge(clk_i)) then
      if (n_rst_i = '0') then
        s_state <= IDLE;
        v_count := 0;
        s_valid <= '0';
      else

        case (s_state) is

          when IDLE =>
            if (enable_i = '1') then
              s_state <= RUNNING;
              s_valid <= '0';
            end if;
          when RUNNING =>
            if (enable_i = '0') then
              s_state <= IDLE;
            else
              v_buffer(v_count) := bit_i;
              if (v_count = DATA_WIDTH - 1) then
                s_data  <= v_buffer;
                s_valid <= '1';
                v_count := 0;
              else
                v_count := v_count + 1;
                s_valid <= '0';
              end if;
            end if;
          when OTHERS =>
            s_state <= IDLE;
            s_valid <= '0';

        end case;

      end if;
    end if;

  end process state_machine;

end architecture rtl;

