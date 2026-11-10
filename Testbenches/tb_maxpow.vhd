library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_max_power_finder is
end entity;

architecture sim of tb_max_power_finder is

constant N : natural := 20;
constant M : natural := 25;
constant Data_Width : natural := 32;
constant Clock_Period : time := 10 ns;

signal aclk_0 : std_logic := '0';
signal aresetn_0 : std_logic := '0';

-- Slave AXIS Interface
signal s_axis_0_tdata  : std_logic_vector(Data_Width-1 downto 0) := (others => '0');
signal s_axis_0_tlast  : std_logic := '0';
signal s_axis_0_tready : std_logic := '1';
signal s_axis_0_tvalid : std_logic := '0';
signal s_axis_0_tuser  : std_logic_vector(Data_Width/2-1 downto 0) := (others => '0');

-- Master AXIS Interface
signal m_axis_0_tdata  : std_logic_vector(Data_Width-1 downto 0) := (others => '0');
signal m_axis_0_tlast  : std_logic := '0';
signal m_axis_0_tready : std_logic := '1';
signal m_axis_0_tvalid : std_logic := '0';
signal m_axis_0_tuser  : std_logic_vector(Data_Width/2-1 downto 0) := (others => '0');

-- Transaction Packet
type transaction_packet_t is record index : integer; data  : integer; end record;

-- FIFO_Slave Parameters(salve data and tuser)
constant FIFO_Slave_depth : natural := 32;
type FIFO_Slave_array_t is array (0 to FIFO_Slave_depth-1) of transaction_packet_t;
signal FIFO_Slave_Mem : FIFO_Slave_array_t :=(others => (index => 0, data => 0));
signal FIFO_Slave_write_en : std_logic := '0';
signal FIFO_Slave_read_en  : std_logic := '0';
signal FIFO_Slave_data_in  : transaction_packet_t;
signal FIFO_Slave_data_out : transaction_packet_t;
signal FIFO_Slave_count : integer range 0 to FIFO_Slave_depth := 0;
signal FIFO_Slave_read_count  : integer range 0 to FIFO_Slave_depth-1 := FIFO_Slave_depth-1;
signal FIFO_Slave_write_count : integer range 0 to FIFO_Slave_depth-1 := FIFO_Slave_depth-1;
signal FIFO_Slave_full  : std_logic := '0';
signal FIFO_Slave_empty : std_logic := '1';

-- FIFO_Master Parameters(salve data and tuser)
constant FIFO_MAster_depth : natural := 32;
type FIFO_Master_array_t is array (0 to FIFO_Master_depth-1) of transaction_packet_t;
signal FIFO_Master_Mem : FIFO_Master_array_t :=(others => (index => 0, data => 0));
signal FIFO_Master_write_en : std_logic := '0';
signal FIFO_Master_read_en  : std_logic := '0';
signal FIFO_Master_data_in  : transaction_packet_t;
signal FIFO_Master_data_out : transaction_packet_t;
signal FIFO_Master_count : integer range 0 to FIFO_Master_depth := 0;
signal FIFO_Master_read_count  : integer range 0 to FIFO_Master_depth-1 := FIFO_Master_depth-1;
signal FIFO_Master_write_count : integer range 0 to FIFO_Master_depth-1 := FIFO_Master_depth-1;
signal FIFO_Master_full  : std_logic := '0';
signal FIFO_Master_empty : std_logic := '1';


begin

-- Clock Generation
aclk_0 <= not aclk_0 after Clock_Period/2;

-- Reset Generation
reset_proc : process
begin
    aresetn_0 <= '0';
    wait for 100 ns;
    aresetn_0 <= '1';
    wait;
end process;

-- AXIS IQ Sample Generator
uut_gen : process
begin
    s_axis_0_tvalid <= '0';
    wait until aresetn_0 = '1';
    wait until rising_edge(aclk_0);
    loop
        -- Forward
        for q in 0 to M loop
            for i in 0 to N loop
                s_axis_0_tdata <=std_logic_vector(to_unsigned(q, Data_Width/2)) & std_logic_vector(to_unsigned(i, Data_Width/2));
                s_axis_0_tuser <= std_logic_vector(to_unsigned(i, Data_Width/2));
                s_axis_0_tvalid <= '1';
                loop
                    wait until rising_edge(aclk_0);
                    exit when s_axis_0_tready = '1';
                end loop;
            end loop;
        end loop;

        -- Reverse
        for q in M downto 0 loop
            for i in N downto 0 loop
                s_axis_0_tdata <= std_logic_vector(to_unsigned(q, Data_Width/2)) & std_logic_vector(to_unsigned(i, Data_Width/2));
                s_axis_0_tuser <= std_logic_vector(to_unsigned(i, Data_Width/2));
                s_axis_0_tvalid <= '1';
                loop
                    wait until rising_edge(aclk_0);
                    exit when s_axis_0_tready = '1';
                end loop;
            end loop;
        end loop;
    end loop;
end process;

-- Power Calculation + FIFO_Slave Input Packing
power_to_fifo_Slave_proc : process

    variable power : integer;
    variable I_val : integer;
    variable Q_val : integer;

begin

    wait until rising_edge(aclk_0);
    FIFO_Slave_write_en <= '0';
    if aresetn_0 = '1' then

        if s_axis_0_tvalid = '1' and s_axis_0_tready = '1' then
            Q_val :=to_integer(signed(s_axis_0_tdata(Data_Width-1 downto Data_Width/2)));
            I_val :=to_integer(signed( s_axis_0_tdata( Data_Width/2-1 downto 0 )));

            -- Power
            power :=(I_val * I_val) + (Q_val * Q_val);

            -- FIFO_Slave Input
            FIFO_Slave_data_in.index <=to_integer(unsigned(s_axis_0_tuser));
            FIFO_Slave_data_in.data <= power;

            -- FIFO_Slave Write Enable
            if FIFO_Slave_full = '0' then FIFO_Slave_write_en <= '1';
            end if;
        end if;
    end if;
end process;

-- FIFO_Slave PROCESS
fifo_Slave_proc : process
begin
    wait until rising_edge(aclk_0);
    if aresetn_0 = '0' then
        FIFO_Slave_write_count <= FIFO_Slave_depth-1;
        FIFO_Slave_read_count  <= FIFO_Slave_depth-1;
        FIFO_Slave_count <= 0;
        FIFO_Slave_data_out <= (index => 0, data => 0);

    else
        -- WRITE ONLY
        if FIFO_Slave_write_en = '1' and FIFO_Slave_read_en  = '0' then
            if FIFO_Slave_count < FIFO_Slave_depth then
                FIFO_Slave_Mem(FIFO_Slave_write_count) <= FIFO_Slave_data_in;
                if FIFO_Slave_write_count = 0 then FIFO_Slave_write_count <= FIFO_Slave_depth-1;
                else FIFO_Slave_write_count <= FIFO_Slave_write_count - 1;
                end if;
                FIFO_Slave_count <= FIFO_Slave_count + 1;
            end if;

        -- READ ONLY
        elsif FIFO_Slave_write_en = '0' and FIFO_Slave_read_en  = '1' then
            if FIFO_Slave_count > 0 then
                FIFO_Slave_data_out <= FIFO_Slave_Mem(FIFO_Slave_read_count);
                 if FIFO_Slave_read_count = 0 then FIFO_Slave_read_count <= FIFO_Slave_depth-1;
                 else FIFO_Slave_read_count <= FIFO_Slave_read_count - 1;
                 end if;
                FIFO_Slave_count <= FIFO_Slave_count - 1;
            end if;

        -- READ + WRITE
        elsif FIFO_Slave_write_en = '1' and   FIFO_Slave_read_en  = '1' then
            FIFO_Slave_Mem(FIFO_Slave_write_count) <= FIFO_Slave_data_in;
            FIFO_Slave_data_out <= FIFO_Slave_Mem(FIFO_Slave_read_count);

            if FIFO_Slave_write_count = 0 then FIFO_Slave_write_count <= FIFO_Slave_depth-1;
            else FIFO_Slave_write_count <= FIFO_Slave_write_count - 1;
            end if;

            if FIFO_Slave_read_count = 0 then FIFO_Slave_read_count <= FIFO_Slave_depth-1;
            else FIFO_Slave_read_count <= FIFO_Slave_read_count - 1;
            end if;
        end if;
    end if;
end process;

-- FIFO_Slave FLAGS
FIFO_Slave_full <= '1' when FIFO_Slave_count = FIFO_Slave_depth else '0';
FIFO_Slave_empty <= '1' when FIFO_Slave_count = 0 else '0';
s_axis_0_tready <= not FIFO_Slave_full; -- axi stream back pressure handle 

fifo_master_proc : process
begin

    wait until rising_edge(aclk_0);
    if aresetn = '1' then
        FIFO_Master_write_count <= FIFO_Slave_depth-1;
        FIFO_Master_read_count  <= FIFO_Slave_depth-1;
        FIFO_Master_count <= 0;
        FIFO_Master_data_out <= (index => 0, data => 0);  
    end if ;

end process ;    

end architecture;