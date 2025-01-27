require 'ffi'

module SimConnect
  extend FFI::Library

  DLL_PATH = File.join(File.dirname(__FILE__), "SimConnect.dll")

  class SIMCONNECT_RECV < FFI::Struct
    pack 1
    layout :dwSize, :ulong,
           :dwVersion, :ulong,
           :dwID, :ulong
  end

  class SIMCONNECT_RECV_EVENT < FFI::Struct
    pack 1
    layout :dwSize, :ulong,
           :dwVersion, :ulong,
           :dwID, :ulong,
           :uGroupID, :ulong,
           :uEventID, :ulong,
           :dwData, :ulong
  end

  class SIMCONNECT_RECV_SIMOBJECT_DATA < FFI::Struct
    pack 1
    layout :dwSize, :ulong,
           :dwVersion, :ulong,
           :dwID, :ulong,
           :dwRequestID, :ulong,
           :dwObjectID, :ulong,
           :dwDefineID, :ulong,
           :dwFlags, :ulong,
           :dwentrynumber, :ulong,
           :dwoutof, :ulong,
           :dwDefineCount, :ulong,
           :dwData, :uint64
  end

  class SIMCONNECT_RECV_EXCEPTION < FFI::Struct
    pack 1
    layout :dwSize, :ulong,
           :dwVersion, :ulong,
           :dwID, :ulong,
           :dwException, :ulong,
           :dwSendID, :ulong,
           :dwIndex, :ulong
  end

  ffi_lib DLL_PATH
  ffi_convention :stdcall

  attach_function :SimConnect_Open, [:pointer, :string, :pointer, :uint, :pointer, :uint], :int
  attach_function :SimConnect_Close, [:pointer], :int
  attach_function :SimConnect_AddToDataDefinition, [:pointer, :int, :string, :string, :int, :float, :ulong], :int
  attach_function :SimConnect_SubscribeToSystemEvent, [:pointer, :ulong, :string], :int
  attach_function :SimConnect_CallDispatch, [:pointer, :pointer, :pointer], :int
  attach_function :SimConnect_GetNextDispatch, [:pointer, :pointer, :pointer], :int
  attach_function :SimConnect_RequestDataOnSimObjectType, [:pointer, :int, :int, :ulong, :int], :int
  attach_function :SimConnect_SetDataOnSimObject, [:pointer, :int, :int, :int, :ulong, :ulong, :pointer], :int

  module SIMCONNECT_RECV_ID
    NULL = 0
    EXCEPTION = 1
    OPEN = 2
    QUIT = 3
    EVENT = 4
    EVENT_OBJECT_ADDREMOVE = 5
    EVENT_FILENAME = 6
    EVENT_FRAME = 7
    SIMOBJECT_DATA = 8
    SIMOBJECT_DATA_BYTYPE = 9
    WEATHER_OBSERVATION = 10
    CLOUD_STATE = 11
    ASSIGNED_OBJECT_ID = 12
    RESERVED_KEY = 13
    CUSTOM_ACTION = 14
    SYSTEM_STATE = 15
    CLIENT_DATA = 16
    EVENT_WEATHER_MODE = 17
    AIRPORT_LIST = 18
    VOR_LIST = 19
    NDB_LIST = 20
    WAYPOINT_LIST = 21
    EVENT_MULTIPLAYER_SERVER_STARTED = 22
    EVENT_MULTIPLAYER_CLIENT_STARTED = 23
    EVENT_MULTIPLAYER_SESSION_ENDED = 24
    EVENT_RACE_END = 25
    EVENT_RACE_LAP = 26
    EVENT_EX1 = 27
    FACILITY_DATA = 28
    FACILITY_DATA_END = 29
    FACILITY_MINIMAL_LIST = 30
    JETWAY_DATA = 31
    CONTROLLERS_LIST = 32
    ACTION_CALLBACK = 33
    ENUMERATE_INPUT_EVENTS = 34
    GET_INPUT_EVENT = 35
    SUBSCRIBE_INPUT_EVENT = 36
    ENUMERATE_INPUT_EVENT_PARAMS = 37
    ENUMERATE_SIMOBJECT_AND_LIVERY_LIST = 38
  end

  REQUEST_0 = 0
  REQUEST_1 = 1
  DEFINITION_0 = 0
  DEFINITION_1 = 1

  SIMCONNECT_DATATYPE_FLOAT64 = 4
  SIMCONNECT_UNUSED = 0xFFFFFFFF

  SIMCONNECT_OBJECT_ID_USER = 0

  @hSimConnect = nil

  def self.connect
    hSimConnect = FFI::MemoryPointer.new :pointer
    SimConnect.SimConnect_Open(hSimConnect, "Request Data via Ruby", nil, 0, nil, 0)
    @hSimConnect = hSimConnect.get_pointer(0)
  rescue
    close
  end

  def self.add_data(definition_id, name, units)
    SimConnect.SimConnect_AddToDataDefinition(@hSimConnect, definition_id, name, units, SIMCONNECT_DATATYPE_FLOAT64, 0.0, SIMCONNECT_UNUSED)
  end

  def self.set_data(struct)
    SimConnect_SetDataOnSimObject(@hSimConnect, DEFINITION_0, SIMCONNECT_OBJECT_ID_USER, 0, 0, struct.size, struct);
  end

  def self.request_data(request_id, definition_id)
    result = SimConnect_RequestDataOnSimObjectType(
      @hSimConnect, request_id, definition_id,
      0, # Object ID (0 == user aircraft)
      0 # Object type
    )
  end

  def self.read_data(request_id)
    loop do
      data_ptr = FFI::MemoryPointer.new :pointer
      size_ptr = FFI::MemoryPointer.new :pointer
      hr = SimConnect_GetNextDispatch(@hSimConnect, data_ptr, size_ptr)
      data_ptr = data_ptr.get_pointer(0)
      recv = SIMCONNECT_RECV.new(data_ptr)
      size = size_ptr.get_int(0)
      # pp(recv:, size:)
      case recv[:dwID]
      when SIMCONNECT_RECV_ID::NULL
        break
      when SIMCONNECT_RECV_ID::SIMOBJECT_DATA_BYTYPE
        data = SIMCONNECT_RECV_SIMOBJECT_DATA.new(data_ptr)
        if data[:dwRequestID] == request_id
          return data_ptr + data.offset_of(:dwData)
        end
      when SIMCONNECT_RECV_ID::EXCEPTION
        exc = SIMCONNECT_RECV_EXCEPTION.new(data_ptr)
        puts "Runtime exception in library: exceptionID=#{exc[:dwException]} index=#{exc[:dwIndex]}"
      else
        puts "Unhandled RECV_ID: #{recv[:dwID]}"
      end
    end
  end

  def self.close
    SimConnect.SimConnect_Close(@hSimConnect) unless @hSimConnect.nil?
  end

  CESSNA_AT_REST_AGL_FT = 3.270
end

class SetPos < FFI::Struct
  layout :latitude, :double,
         :longitude, :double,
         :altitude, :double

  def self.add_definition
    SimConnect.add_data(0, "Plane Latitude", "degrees latitude")
    SimConnect.add_data(0, "Plane Longitude", "degrees longitude")
    SimConnect.add_data(0, "Plane Alt Above Ground", "feet")
  end
end

class Environment < FFI::Struct
  layout :time, :double,
         :agl, :double,
         :longitude, :double,
         :latitude, :double,
         :precip_rate, :double,
         :precip_state, :double,
         :pressure, :double,
         :temperature, :double,
         :visibility, :double,
         :wind_direction, :double,
         :wind_velocity, :double,
         :in_cloud, :double,
         :sea_level_pressure, :double

  def self.add_definition
    SimConnect.add_data(1, "Absolute Time", "seconds")
    SimConnect.add_data(1, "Plane Alt Above Ground", "feet")
    SimConnect.add_data(1, "Plane Latitude", "radians")
    SimConnect.add_data(1, "Plane Longitude", "radians")
    SimConnect.add_data(1, "Ambient Precip Rate", "millimeters")
    SimConnect.add_data(1, "Ambient Precip State", "mask")
    SimConnect.add_data(1, "Ambient Pressure", "millibars")
    SimConnect.add_data(1, "Ambient Temperature", "celsius")
    SimConnect.add_data(1, "Ambient Visibility", "miles")
    SimConnect.add_data(1, "Ambient Wind Direction", "degrees")
    SimConnect.add_data(1, "Ambient Wind Velocity", "knots")
    SimConnect.add_data(1, "Ambient In Cloud", "bool")
    SimConnect.add_data(1, "Sea Level Pressure", "millibars")
  end

  def to_h
    members.zip(values).to_h
  end
end

def teleport(latitude, longitude)
  pos = SetPos.new
  pos[:latitude] = latitude
  pos[:longitude] = longitude
  pos[:altitude] = SimConnect::CESSNA_AT_REST_AGL_FT
  SimConnect.set_data(pos)
end

def setup_simconnect
  SimConnect.connect
  SetPos.add_definition
  Environment.add_definition
end

def observe_local_weather
  SimConnect.request_data(1, 1)
  sleep(0.5)
  ptr = SimConnect.read_data(1)
  Environment.new(ptr).to_h
end