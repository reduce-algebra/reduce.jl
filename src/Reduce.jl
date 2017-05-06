module Reduce
using Compat; import Compat.String

#   This file is part of Reduce.jl. It is licensed under the MIT license
#   Copyright (C) 2017 Michael Reed

immutable ReduceSession <: Base.AbstractPipe
  input::Pipe; output::Pipe; process::Base.Process
  function ReduceSession()
    # Setup pipes and reduce process
    input = Pipe(); output = Pipe()
    process = spawn(`redpsl`, (input, output, STDERR))
    # Close the unneeded ends of Pipes
    close(input.out); close(output.in)
    return new(input, output, process); end; end

Base.kill(rs::ReduceSession) = kill(rs.process)
Base.process_exited(rs::ReduceSession) = process_exited(rs.process)

function Base.write(rs::ReduceSession, input::Compat.String)
  # The line break right ..v.. there is apparently very important...
  write(rs.input,"$input; symbolic write(string 4);\n"); end

if VERSION < v"0.5.0"
  function Base.write(rs::ReduceSession, input::UTF8String)
    write(rs.input, "$input; symbolic write(string 4);\n"); end
  function Base.write(rs::ReduceSession, input::ASCIIString)
    write(rs.input, "$input; symbolic write(string 4);\n"); end
end

function ReduceCheck(output)
  contains(output,"***** ") && throw(ReduceError(split(output,'\n')[end-2])); end

const EOT = Char('$') # end of transmission character
function Base.read(rs::ReduceSession)
  output = readuntil(rs.output,Char(4)) |> String; readavailable(rs.output);
  ReduceCheck(output); output = split(output,EOT)[1] #|> str -> rstrip(str,EOT)
  output = replace(output,r"[0-9]: ",EOT); return split(output,EOT)[end]; end

include("rexpr.jl")

## io

export string, show

import Base: string, show

string(r::RExpr) = r.str; show(io::IO, r::RExpr) = print(io, r.str)

@compat function show(io::IO, ::MIME"text/plain", r::RExpr)
  rcall(ra"on nat"); write(rs, r.str); output = readuntil(rs.output,Char(4)) |> String
  readavailable(rs.output); ReduceCheck(output); rcall(ra"off nat")
  output = join(split(output,"\n\n")[1:end-1])
  output = replace(output,r": ",EOT); print(io,split(output,EOT)[end]); end

@compat function show(io::IO, ::MIME"text/latex", r::RExpr)
  rcall(ra"on latex"); write(rs, r.str); output = read(rs)
  ReduceCheck(output); rcall(ra"off latex")
  print(io,"\$\$"*join(split(output,"\n")[2:end-3],"\n")*"\$\$"); end

## Setup

try
  if is_unix(); Reduce.@compat readstring(`which redpsl`)
  else; Reduce.@compat readstring(`which redpsl`); end
catch err
  error("Looks like Reduce is either not installed or not in the path"); end

# Server setup

const rs = ReduceSession()	# Spin up a Reduce session
atexit(() -> kill(rs))  	# Kill the session on exit

write(rs,"off nat")
redpsl = readuntil(rs.output,Char(4)) |> String; readavailable(rs.output);
ReduceCheck(redpsl); redpsl = split(redpsl,EOT)[1] |> str -> rstrip(str,EOT)
println(split(String(redpsl),'\n')[end-3])
ra"load_package rlfi" |> rcall

# REPL setup
#repl_active = isdefined(Base, :active_repl)	# Is an active repl defined?
#interactive = isinteractive()				# In interactive mode?

#if repl_active && interactive
#  repl_init(Base.active_repl)
#end

end # module
