# Build and compiler directories
BINDIR = ./bin
BUILDDIR = build

# Compiler settings
SPCOMP = ${BINDIR}/spcomp
INCLUDES = -iinclude
FLAGS = -v0

# Input files
TARGETS = SurfTimerNoJail.smx SurfTimer.smx SurfTimerHud.smx SurfTimerZones.smx SurfTimerUser.smx SurfTimerMap.smx SurfTimerTest.smx SurfTimerRank.smx SurfTimerRules.smx


# SRCDS Configuration
SRCDS = /home/gameserver/srcds/SurfServer/cstrike
ADDONS = ${SRCDS}/addons
SM = ${ADDONS}/sourcemod
SMPLUGINS = ${SM}/plugins
SMCONFIGS = ${SM}/configs

SRCDS_DEV = /home/gameserver/srcds/SurfServerDev/css/cstrike
ADDONS_DEV = ${SRCDS_DEV}/addons
SM_DEV = ${ADDONS_DEV}/sourcemod
SMPLUGINS_DEV = ${SM_DEV}/plugins
SMCONFIGS_DEV = ${SM_DEV}/configs

all: ${TARGETS} install

.PHONY: version.inc install clean run

SurfTimer.smx: SurfTimer.sp ${SPCOMP} version.inc
	-@mkdir -p ${BUILDDIR}
	${SPCOMP} ${INCLUDES} ${FLAGS} $< -o${BUILDDIR}/$@

SurfTimerHud.smx: SurfTimerHud.sp ${SPCOMP} version.inc
	-@mkdir -p ${BUILDDIR}
	${SPCOMP} ${INCLUDES} ${FLAGS} $< -o${BUILDDIR}/$@

SurfTimerZones.smx: SurfTimerZones.sp ${SPCOMP} version.inc
	-@mkdir -p ${BUILDDIR}
	${SPCOMP} ${INCLUDES} ${FLAGS} $< -o${BUILDDIR}/$@

SurfTimerUser.smx: SurfTimerUser.sp ${SPCOMP} version.inc
	-@mkdir -p ${BUILDDIR}
	${SPCOMP} ${INCLUDES} ${FLAGS} $< -o${BUILDDIR}/$@

SurfTimerMap.smx: SurfTimerMap.sp ${SPCOMP} version.inc
	-@mkdir -p ${BUILDDIR}
	${SPCOMP} ${INCLUDES} ${FLAGS} $< -o${BUILDDIR}/$@

SurfTimerTest.smx: SurfTimerTest.sp ${SPCOMP} version.inc
	-@mkdir -p ${BUILDDIR}
	${SPCOMP} ${INCLUDES} ${FLAGS} $< -o${BUILDDIR}/$@

SurfTimerRank.smx: SurfTimerRank.sp ${SPCOMP} version.inc
	-@mkdir -p ${BUILDDIR}
	${SPCOMP} ${INCLUDES} ${FLAGS} $< -o${BUILDDIR}/$@

SurfTimerNoJail.smx: SurfTimerNoJail.sp ${SPCOMP} version.inc
	-@mkdir -p ${BUILDDIR}
	${SPCOMP} ${INCLUDES} ${FLAGS} $< -o${BUILDDIR}/$@

SurfTimerRules.smx: SurfTimerRules.sp ${SPCOMP} version.inc
	-@mkdir -p ${BUILDDIR}
	${SPCOMP} ${INCLUDES} ${FLAGS} $< -o${BUILDDIR}/$@

SurfTimerRecorder.smx: SurfTimerRecorder.sp ${SPCOMP} version.inc
	-@mkdir -p ${BUILDDIR}
	${SPCOMP} ${INCLUDES} ${FLAGS} $< -o${BUILDDIR}/$@	

clean:
	-@rm -f ${TARGETS} >/dev/null 2>&1
	-@rm -Rf ${BUILDDIR} >/dev/null 2>&1 

install: ${TARGETS}
	if test -d ${SMPLUGINS}; then cp ${BUILDDIR}/SurfTimer.smx ${SMPLUGINS}/; fi
	if test -d ${SMPLUGINS}; then cp ${BUILDDIR}/SurfTimerHud.smx ${SMPLUGINS}/; fi
	if test -d ${SMPLUGINS}; then cp ${BUILDDIR}/SurfTimerZones.smx ${SMPLUGINS}/; fi
	if test -d ${SMPLUGINS}; then cp ${BUILDDIR}/SurfTimerUser.smx ${SMPLUGINS}/; fi
	if test -d ${SMPLUGINS}; then cp ${BUILDDIR}/SurfTimerMap.smx ${SMPLUGINS}/; fi
	if test -d ${SMPLUGINS}; then cp ${BUILDDIR}/SurfTimerTest.smx ${SMPLUGINS}/; fi
	if test -d ${SMPLUGINS}; then cp ${BUILDDIR}/SurfTimerRank.smx ${SMPLUGINS}/; fi
	if test -d ${SMPLUGINS}; then cp ${BUILDDIR}/SurfTimerNoJail.smx ${SMPLUGINS}/; fi
	if test -d ${SMPLUGINS}; then cp ${BUILDDIR}/SurfTimerRules.smx ${SMPLUGINS}/; fi

run: install
	sh ${SRCDS}/../start-dev.sh

runonly:
	sh ${SRCDS}/../start-dev.sh	

deploydev: ${TARGETS}
	if test -d ${SMPLUGINS_DEV}; then cp ${BUILDDIR}/SurfTimer.smx ${SMPLUGINS_DEV}/; fi
	if test -d ${SMPLUGINS_DEV}; then cp ${BUILDDIR}/SurfTimerHud.smx ${SMPLUGINS_DEV}/; fi
	if test -d ${SMPLUGINS_DEV}; then cp ${BUILDDIR}/SurfTimerZones.smx ${SMPLUGINS_DEV}/; fi
	if test -d ${SMPLUGINS_DEV}; then cp ${BUILDDIR}/SurfTimerUser.smx ${SMPLUGINS_DEV}/; fi
	if test -d ${SMPLUGINS_DEV}; then cp ${BUILDDIR}/SurfTimerMap.smx ${SMPLUGINS_DEV}/; fi
	if test -d ${SMPLUGINS_DEV}; then cp ${BUILDDIR}/SurfTimerTest.smx ${SMPLUGINS_DEV}/; fi
	if test -d ${SMPLUGINS_DEV}; then cp ${BUILDDIR}/SurfTimerRank.smx ${SMPLUGINS_DEV}/; fi
	if test -d ${SMPLUGINS_DEV}; then cp ${BUILDDIR}/SurfTimerNoJail.smx ${SMPLUGINS_DEV}/; fi
	if test -d ${SMPLUGINS_DEV}; then cp ${BUILDDIR}/SurfTimerRules.smx ${SMPLUGINS_DEV}/; fi

