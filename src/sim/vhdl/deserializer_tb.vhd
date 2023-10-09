----------------------------------------------------------------------------------
-- Company:
-- Engineer:
--
-- Create Date: 04/15/2020 10:09:30 PM
-- Design Name:
-- Module Name: test_ro - Behavioral
-- Project Name:
-- Target Devices:
-- Tool Versions:
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

library coso_lib;
  use coso_lib.helper_functions.all;

entity deserializer_tb is
end entity deserializer_tb;

architecture rtl of deserializer_tb is

  constant DATA_WIDTH  : integer := 32;
  constant HALF_PERIOD : time := 10 ns;
  constant PERIOD      : time := 2 * HALF_PERIOD;

  signal s_clk    : std_logic := '0';
  signal s_bit    : std_logic;
  signal s_enable : std_logic;
  signal s_n_rst  : std_logic;
  signal s_valid  : std_logic;
  signal s_data   : std_logic_vector(DATA_WIDTH -1 downto 0);

begin

    deserializer_inst_0 : entity coso_lib.deserializer_0
    generic map (
      data_width => data_width
    )
    port map (
      clk_i => s_clk,
      bit_i => s_bit,
      enable_i => s_enable,
      n_rst_i => s_n_rst,
      data_o => s_data,
      valid_o => s_valid
    );

  s_clk <= not s_clk after HALF_PERIOD;

  tb : process
    variable v_expected_data  : std_logic_vector(DATA_WIDTH -1 downto 0);
    variable v_expected_valid : std_logic;
  begin

    s_enable <= '1';
    s_n_rst  <= '0';
    s_bit    <= '0';
    wait for PERIOD;
    s_n_rst  <= '1';
    s_bit    <= '1';
    wait until s_valid = '1';
    v_expected_data := (others => '1');
    assert (s_data = v_expected_data)
      report "test 1: counter_out should be " & slv_to_string(v_expected_data) & ", but is " & slv_to_string(s_data)
      severity FAILURE;

    s_bit <= '0';
    wait until s_valid = '1';
    v_expected_data := (others => '0');
    assert (s_data = v_expected_data)
      report "test 2: counter_out should be " & slv_to_string(v_expected_data) & ", but is " & slv_to_string(s_data)
      severity FAILURE;

    s_bit <= '1';
    wait for PERIOD;
    s_bit <= '0';
    wait until s_valid = '1';
    v_expected_data := (0 =>'1', others => '0');
    assert (s_data = v_expected_data)
      report "test 3: counter_out should be " & slv_to_string(v_expected_data) & ", but is " & slv_to_string(s_data)
      severity FAILURE;

    wait until s_valid = '0';
    s_n_rst <= '0';
    wait for PERIOD;
    s_n_rst <= '1';
    s_bit   <= '0';
    while s_valid = '0' loop
      wait for PERIOD;
      s_bit <= not s_bit;
    end loop;
    v_expected_data := "01010101010101010101010101010101";
    assert (s_data = v_expected_data)
      report "test 4: counter_out should be " & slv_to_string(v_expected_data) & ", but is " & slv_to_string(s_data)
      severity FAILURE;

    wait for PERIOD;
    s_bit   <= not s_bit;
    while s_valid = '0' loop
      wait for PERIOD;
      s_bit <= not s_bit;
    end loop;
    v_expected_data := "01010101010101010101010101010101";
    assert (s_data = v_expected_data)
      report "test 5: counter_out should be " & slv_to_string(v_expected_data) & ", but is " & slv_to_string(s_data)
      severity FAILURE;

    wait for PERIOD;
    v_expected_valid := '0';
    assert (s_valid = v_expected_valid)
      report "test 5: valid should be " & std_logic'image(v_expected_valid)
      & "after PERIOD, but is " & std_logic'image(s_valid)
      severity FAILURE;
    s_bit   <= 'X';
    wait for PERIOD;
    s_bit   <= '0';
    for i in 1 to 27 loop
      wait for PERIOD;
      s_bit <= not s_bit;
    end loop;
    wait for PERIOD;
    s_bit   <= '-';
    wait for PERIOD;
    s_bit   <= 'U';
    wait for PERIOD;
    s_bit   <= 'X';
    v_expected_data  := "-1010101010101010101010101010X01";
    assert (s_data = v_expected_data)
      report "test 6: counter_out should be " & slv_to_string(v_expected_data) & ", but is " & slv_to_string(s_data)
      severity FAILURE;
    v_expected_valid := '1';
    assert (s_valid = v_expected_valid)
      report "test 6: valid should be " & std_logic'image(v_expected_valid) & ", but is " & std_logic'image(s_valid)
      severity FAILURE;
    wait for PERIOD;
    v_expected_valid := '0';
    assert (s_valid = v_expected_valid)
      report "test 6: valid should be " & std_logic'image(v_expected_valid) & ", but is " & std_logic'image(s_valid)
      severity FAILURE;

    s_bit   <= '0';
    while s_valid = '0' loop
      wait for PERIOD;
      s_bit <= not s_bit;
    end loop;
    v_expected_data := "101010101010101010101010101010XU";
    assert (s_data = v_expected_data)
      report "test 7: counter_out should be " & slv_to_string(v_expected_data) & ", but is " & slv_to_string(s_data)
      severity FAILURE;

  report "End deserializer test" severity NOTE;
        std.env.finish;

  end process tb;

end architecture rtl;
