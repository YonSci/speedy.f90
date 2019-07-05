# Fortran compiler
FC=ifort

# Set variables depending on target
default : COMPOPTS = $(OPT) $(BASE)
profile : COMPOPTS = -pg $(BASE)

# Default
default : base_target

# For profiling
profile : base_target

# Base compiler options (always used)
BASE=-r8 -convert big_endian -warn all

# Optimisation flags (disabled for debugging, profiling etc.)
OPT=-Ofast

# # Location of NetCDF module (netcdf.mod)
INC=-I$(NETCDF)/include

# Library flags
LIB=-L$(NETCDF)/lib -lnetcdff -lnetcdf

FILES= \
	   auxiliaries.o \
	   boundaries.o \
	   convection.o \
       coupler.o \
	   date.o \
	   diagnostics.o \
	   dynamical_constants.o \
	   forcing.o \
	   fourier.o \
	   geometry.o \
 	   geopotential.o \
	   horizontal_diffusion.o \
	   humidity.o \
	   implicit.o \
       initialization.o \
	   land_model.o \
	   large_scale_condensation.o \
	   legendre.o \
	   longwave_radiation.o \
	   matrix_inversion.o \
	   input_output.o \
	   interpolation.o \
	   mod_radcon.o \
	   params.o \
	   physics.o \
	   physical_constants.o \
	   prognostics.o \
	   sea_model.o \
	   shortwave_radiation.o \
	   spectral.o \
       fftpack.o \
	   sppt.o \
	   surface_fluxes.o \
	   tendencies.o \
	   time_stepping.o \
	   vertical_diffusion.o

%.o: %.f90
	$(FC) $(COMPOPTS) -c $< $(INC)

base_target: $(FILES) speedy.o
	$(FC) $(COMPOPTS) $(FILES) speedy.o -o speedy $(LIB)

.PHONY: clean
clean:
	rm -f *.o *.mod

speedy.o               : params.o date.o input_output.o shortwave_radiation.o time_stepping.o\
                         diagnostics.o
auxiliaries.o          : params.o
boundaries.o           : physical_constants.o params.o input_output.o spectral.o
convection.o           : params.o physical_constants.o
coupler.o              : land_model.o sea_model.o
fourier.o              : params.o geometry.o fftpack.o
geometry.o             : params.o physical_constants.o
geopotential.o         : params.o physical_constants.o geometry.o
horizontal_diffusion.o : params.o dynamical_constants.o
humidity.o             : params.o
implicit.o             : params.o dynamical_constants.o physical_constants.o geometry.o\
                         horizontal_diffusion.o matrix_inversion.o
initialization.o       : coupler.o params.o date.o input_output.o time_stepping.o boundaries.o\
                         spectral.o sea_model.o physics.o geopotential.o prognostics.o forcing.o
forcing.o              : dynamical_constants.o shortwave_radiation.o params.o \
                         physical_constants.o boundaries.o date.o land_model.o mod_radcon.o\
						 surface_fluxes.o date.o sea_model.o longwave_radiation.o humidity.o\
						 horizontal_diffusion.o
land_model.o           : params.o date.o interpolation.o input_output.o boundaries.o\
                         auxiliaries.o
large_scale_condensation.o : params.o physical_constants.o
legendre.o             : params.o physical_constants.o geometry.o
diagnostics.o          : params.o spectral.o
prognostics.o          : params.o dynamical_constants.o physical_constants.o geometry.o\
                         boundaries.o diagnostics.o spectral.o input_output.o
input_output.o         : params.o  physical_constants.o date.o spectral.o geometry.o
interpolation.o        : params.o date.o
physical_constants.o   : params.o
mod_radcon.o           : params.o
physics.o              : params.o coupler.o physical_constants.o boundaries.o land_model.o\
                         sea_model.o sppt.o convection.o large_scale_condensation.o surface_fluxes.o\
                         vertical_diffusion.o shortwave_radiation.o longwave_radiation.o humidity.o\
                         geometry.o auxiliaries.o
longwave_radiation.o   : params.o physical_constants.o mod_radcon.o geometry.o
sea_model.o            : params.o input_output.o boundaries.o geometry.o interpolation.o\
 						 date.o auxiliaries.o mod_radcon.o
shortwave_radiation.o  : params.o mod_radcon.o geometry.o
surface_fluxes.o       : params.o physical_constants.o mod_radcon.o land_model.o humidity.o
spectral.o             : params.o physical_constants.o legendre.o fourier.o
sppt.o                 : params.o physical_constants.o spectral.o
tendencies.o           : params.o implicit.o prognostics.o physical_constants.o geometry.o\
                         physics.o spectral.o geopotential.o
time_stepping.o        : dynamical_constants.o params.o prognostics.o tendencies.o\
                         horizontal_diffusion.o
vertical_diffusion     : params.o physical_constants.o geometry.o
