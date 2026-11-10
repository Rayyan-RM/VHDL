Library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_max_power_finfer is 

end entity;

architecture sim of tb_max_power_finder is 

constant N : natural := 20; -- Max Range for I and user Index 
constant M : natural := 25; -- Max Range for Q
constant Data_Width : natural := 32 ; --width of data salve and master 
constant Clock_Period : time := 10 ns ;  -- Frequency 100MHz or Period time is 10 ns .

signal aclk_0 : std_logic := 0;
signal aresetn_0: std_logic := 0;

---salve interface (Inputs to DUT)
signal s_axis_0_tdata : std_logic_vector(Data_Width downto 0) := (others=> '0');
signal s_axis_0_tlast : std_logic := 0;
signal s_axis_0_tready : std_logic := 0;
signal s_axis_0_tvalid : std_logic := 0;
signal s_axis_0_tuser : std_logic_vector (Data_Width/2 -1 downto 0);

---Master  interface (Inputs to DUT)
signal m_axis_0_tdata : std_logic_vector(31 downto 0) := (others=> '0');
signal m_axis_0_tlast : std_logic := 0;
signal m_axis_0_tready : std_logic := 0;
signal m_axis_0_tvalid : std_logic := 0;
signal m_axis_0_tuser : std_logic_vector (Data_Width/2 -1 downto 0);

--packeting data and corresponding user 
type transaction_packet_t is record 
        index : integer ;
        data : integer ;
end record;


--FIFO Parameters 
constant FIFO_depth : natural := 32;
type FIFO_array_t is array ( 0 to FIFO_depth-1) of transaction_packet_t; --- hold the recoding data 

signal FIFO_Mem : FIFO_array_t := (others => (user_id => 0 , data=> 0));
signal FIFO_write_en : std_logic := 0 ;
signal FIFO_data_in : integer range 0 to FIFO_depth-1 := 0;
signal FIFO_read_en : std_logic := 0 ;
signal FIFO_data_out : integer range 0 to FIFO_depth-1 := 0;
signal FIFO_read_count : integer range 0 to FIFO_depth := FIFO_depth;
signal FIFO_write_count : integer range 0 to FIFO_depth := FIFO_depth;
signal FIFO_full : std_logic := 0;
signal FIFO_empty : std_logic := 0;

begin 

--clock generation (Concurrent)
aclk <= not aclk after Clock_

---process for generating IQ samplese and salve axi interface data 
uut_gen : process
begin
    s_axis_0_tvalid <= '0';
    wait until aresetn_0 = '1';
    wait until rising_edge(aclk_0);
    loop
        -- Forward
        for q in 0 to M loop
            for i in 0 to N loop
                s_axis_0_tdata <=std_logic_vector(to_unsigned(i, Data_Width/2)) & std_logic_vector(to_unsigned(q, Data_Width/2));
                s_axis_0_tuser <=std_logic_vector(to_unsigned(i, Data_Width/2));
                s_axis_0_tvalid <= '1';

                loop
                    wait until rising_edge(aclk_0);
                    exit when s_axis_0_tready = '1';
                end loop;

            end loop;
        end loop;

        -- Reverse
        for q in reverse M downto 0 loop
            for i in reverse N downto 0 loop
                s_axis_0_tdata <= std_logic_vector(to_unsigned(i, Data_Width/2)) & std_logic_vector(to_unsigned(q, Data_Width/2));
                s_axis_0_tuser <=std_logic_vector(to_unsigned(i, Data_Width/2));
                s_axis_0_tvalid <= '1';

                loop
                    wait until rising_edge(aclk_0);
                    exit when s_axis_0_tready = '1';
                end loop;

            end loop;
        end loop;
    end loop;
end process;

-- Power calculation
stimulus_proc : process
begin
    ...
end process;

---Power Calculation
power_calc_proc : process(aclk_0)
    variable power : integer;
    variable I_val : integer;
    variable Q_val : integer;
begin
    if rising_edge(aclk_0) then
        if s_axis_0_tvalid = '1' and s_axis_0_tready = '1' then
            -- Extract I/Q
            Q_val := to_integer(signed(s_axis_0_tdata(Data_Width-1 downto Data_Width/2)));
            I_val := to_integer(signed(s_axis_0_tdata(Data_Width/2-1 downto 0)));
            -- Calculate power
            power := (I_val * I_val) + (Q_val * Q_val);
        end if;
    end if;
end process;

--- FIFO for Slave side data 

fifo_proc : process
begin

    wait until rising_edge(aclk_0);

    if aresetn_0 = '0' then

        FIFO_write_count <= FIFO_depth-1;
        FIFO_read_count  <= FIFO_depth-1;
        FIFO_count <= 0;
        FIFO_data_out <= 0;

    else

        if FIFO_write_en = '1' and FIFO_read_en  = '0' then
            if FIFO_count < FIFO_depth then
                FIFO_mem(FIFO_write_count) <= FIFO_data_in;
                if FIFO_write_count = 0 then FIFO_write_count <= FIFO_depth-1;
                else FIFO_write_count <= FIFO_write_count - 1;
                end if;
                FIFO_count <= FIFO_count + 1;
            end if;
        
        elsif FIFO_write_en = '0' and FIFO_read_en  = '1' then
            if FIFO_count > 0 then
                FIFO_data_out <= FIFO_mem(FIFO_read_count);
                if FIFO_read_count = 0 then FIFO_read_count <= FIFO_depth-1;
                else FIFO_read_count <= FIFO_read_count - 1;
                end if;
                FIFO_count <= FIFO_count - 1;
            end if;
        
        elsif FIFO_write_en = '1' and FIFO_read_en  = '1' then
            FIFO_mem(FIFO_write_count) <= FIFO_data_in;
            FIFO_data_out <= FIFO_mem(FIFO_read_count);

            if FIFO_write_count = 0 then FIFO_write_count <= FIFO_depth-1;
            else FIFO_write_count <= FIFO_write_count - 1;
            end if;

            if FIFO_read_count = 0 then FIFO_read_count <= FIFO_depth-1;
            else FIFO_read_count <= FIFO_read_count - 1;
            end if;
        end if;
    end if;
end process;

FIFO_full <= '1' when FIFO_count = FIFO_depth else '0';
FIFO_empty <= '1' when FIFO_count = 0 else '0';


end architecture;