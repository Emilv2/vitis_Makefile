
library ieee;
  use ieee.std_logic_1164.all;
  use ieee.std_logic_arith.all;
  use ieee.std_logic_unsigned.all;
  use ieee.numeric_std.all;

library unisim;
  use unisim.vcomponents.all;

library coso_lib;
  use coso_lib.helper_functions.all;

entity cscnt_ro_counter is
  port (
    clk_i          : in    std_logic;
    ack_i          : in    std_logic;
    enable_i       : in    std_logic;
    sel_ro_i       : in    std_logic;
    sel_cscnt_i    : in    std_logic;
    counter_rst_i  : in    std_logic;
    control_0_i    : in    std_logic_vector(5 downto 0);
    control_1_i    : in    std_logic_vector(5 downto 0);
    counter_o      : out   std_logic_vector(29 downto 0);
    prev_counter_o : out   std_logic_vector(29 downto 0);
    cscnt_valid_o  : out   std_logic;
    error_o        : out   std_logic;
    cscnt_o        : out   std_logic_vector(31 downto 0)
  );
end entity cscnt_ro_counter;

architecture rtl of cscnt_ro_counter is

  type t_state is (
    WAIT_FOR_RISING_EDGE,
    WAIT_FOR_ZERO_RISING,
    WAIT_FOR_ZERO_FALLING,
    WAIT_FOR_FALLING_EDGE
  );

  signal s_state                : t_state;
  signal s_counter              : std_logic_vector(29 downto 0);
  signal s_prev_counter         : std_logic_vector(29 downto 0);
  signal s_prev_counter_rising  : std_logic_vector(29 downto 0);
  signal s_prev_counter_falling : std_logic_vector(29 downto 0);
  signal s_clk_counter          : std_logic;
  signal s_rst_counter          : std_logic;
  signal s_rst_cscnt            : std_logic;
  signal s_ro_out_0             : std_logic;
  signal s_ro_out_1             : std_logic;
  signal s_enable_ro_0          : std_logic;
  signal s_enable_ro_1          : std_logic;
  signal s_beat                 : std_logic;
  signal s_valid                : std_logic;
  signal s_ack_d                : std_logic;
  signal s_ack_dd               : std_logic;
  signal s_ack_ddd              : std_logic;

begin

  ro_inst_0 : entity coso_lib.mux_ro2
    generic map (
      ro_length => 3
    )
    port map (
      enable_i  => s_enable_ro_0,
      control_i => control_0_i,
      output_o  => s_ro_out_0
    );

  ro_inst_1 : entity coso_lib.mux_ro2
    generic map (
      ro_length => 3
    )
    port map (
      enable_i  => s_enable_ro_1,
      control_i => control_1_i,
      output_o  => s_ro_out_1
    );

  --async_ro_counter_inst : entity coso_lib.async_counter
  async_ro_counter_inst : entity coso_lib.counter
    generic map (
      max => 1_000_000_000
    )
    port map (
      clk_i      => s_clk_counter,
      rst_i      => s_rst_counter,
      overflow_o => error_o,
      counter_o  => s_counter
    );

  beat_ff : fdce
    port map (
      clr => '0',
      ce  => '1',
      d   => s_ro_out_0,
      c   => s_ro_out_1,
      q   => s_beat
    );

  synchronization : process (s_ro_out_1) is
  begin

    if (rising_edge(s_ro_out_1)) then
         s_ack_d <= ack_i;
         s_ack_dd <= s_ack_d;
         s_ack_ddd <= s_ack_dd;
    end if;

  end process synchronization;

  beat_store_rising_edge : process (s_beat) is
  begin

    if (rising_edge(s_beat)) then
      s_prev_counter_rising <= s_counter;
    end if;

  end process beat_store_rising_edge;

  beat_store_falling_edge : process (s_beat) is
  begin

    if (falling_edge(s_beat)) then
      s_prev_counter_falling <= s_counter;
    end if;

  end process beat_store_falling_edge;

  reset_counter : process (s_ro_out_1) is
  begin

    if (falling_edge(s_ro_out_1)) then

      case (s_state) is

        when WAIT_FOR_RISING_EDGE =>
          s_rst_cscnt <= '0';
          if (s_beat = '1') then
            s_state <= WAIT_FOR_ZERO_RISING;
          end if;

        when WAIT_FOR_ZERO_RISING =>
          if (is_all(s_counter, '0')) then
            s_rst_cscnt <= '0';
            s_state <= WAIT_FOR_FALLING_EDGE;
          else
            s_rst_cscnt <= '1';
            s_prev_counter <= s_prev_counter_rising;
          end if;

        when WAIT_FOR_FALLING_EDGE =>
          s_rst_cscnt <= '0';
          if (s_beat = '0') then
            s_state <= WAIT_FOR_ZERO_FALLING;
          end if;

        when WAIT_FOR_ZERO_FALLING =>
          if (is_all(s_counter, '0')) then
            s_rst_cscnt <= '0';
            s_state <= WAIT_FOR_RISING_EDGE;
          else
            s_rst_cscnt <= '1';
            s_prev_counter <= s_prev_counter_falling;
            s_prev_counter(15) <= '1';
          end if;

        when others =>
        s_rst_cscnt <= '0';
        s_state <= WAIT_FOR_RISING_EDGE;

      end case;

    end if;

  end process reset_counter;

  valid : process (s_rst_counter, clk_i) is
  begin

    if (s_rst_counter = '1') then
      s_valid <= '1';
    elsif (rising_edge(clk_i)) then
      if (s_ack_ddd = '1') then
         s_valid <= '0';
      end if;
    end if;

  end process valid;

  counter_o <= s_counter;

  s_enable_ro_0 <= enable_i when sel_ro_i = '0' or sel_cscnt_i = '1' else
                   '0';

  s_enable_ro_1 <= enable_i when sel_ro_i = '1' or sel_cscnt_i = '1' else
                   '0';

  s_clk_counter <= not s_ro_out_1 when sel_ro_i = '1' or sel_cscnt_i = '1' else
                   s_ro_out_0;

  s_rst_counter <= counter_rst_i when sel_cscnt_i = '0' else
                   s_rst_cscnt;
  -- s_rst_cscnt when sel_ro_i = '0' else
  -- s_beat;

  cscnt_valid_o <= s_valid;

  prev_counter_o <= s_prev_counter;

end architecture rtl;

